import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:unipool/core/constants.dart';
import '../models/carpool_applicant_model.dart';
import 'package:unipool/features/carpool/models/carpool_request_model.dart';
import 'package:unipool/features/carpool/models/carpool_group_model.dart';
import 'package:unipool/features/carpool/models/ride_payment_model.dart';
import 'package:unipool/features/carpool/providers/carpool_provider.dart';
import 'package:unipool/features/carpool/providers/payment_provider.dart';
import '../services/carpool_service.dart';
import '../services/payment_service.dart';
import '../widgets/applicant_card.dart';
import '../widgets/ride_status_badge.dart';
import 'end_ride_split_dialog.dart';
import 'group_chat_screen.dart';
import 'payment_screen.dart';
import 'report_screen.dart';

class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final _service = CarpoolService();
  final _paymentService = PaymentService();
  bool _justAppliedPassenger = false;
  bool _justAppliedDriver = false;
  bool _endingRide = false;
  bool _didEndRide = false;
  StreamSubscription<CarpoolRequestModel?>? _requestSub;
  String? _prevStatus;

  @override
  void initState() {
    super.initState();
    _requestSub = _service.getRequestById(widget.requestId).listen((request) {
      if (request == null || !mounted) return;
      if (_prevStatus == CarpoolRequestStatuses.inProgress && 
          request.status == CarpoolRequestStatuses.completed) {
        if (!_didEndRide) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen(requestId: widget.requestId)));
        }
      }
      _prevStatus = request.status;
    });
  }

  @override
  void dispose() {
    _requestSub?.cancel();
    super.dispose();
  }

  Future<void> _showApplicantDetails(String userId) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection(AppCollections.users)
              .doc(userId)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final userData = snapshot.data?.data() ?? const <String, dynamic>{};
            final fullName =
                (userData[AppFields.userFullName] as String?)
                        ?.trim()
                        .isNotEmpty ==
                    true
                ? (userData[AppFields.userFullName] as String).trim()
                : userId;
            final verificationStatus =
                (userData[AppFields.userVerificationStatus] as String?) ??
                'unverified';
            final university =
                (userData['university'] as String?)?.trim() ?? '';
            final email =
                (userData[AppFields.userEmail] as String?)?.trim() ?? '';
            final phone =
                (userData[AppFields.userPhoneNumber] as String?)?.trim() ?? '';
            final initials = _initials(fullName);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 8,
                  bottom: MediaQuery.of(context).padding.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 34,
                        backgroundColor: const Color(0xFFE8F7F5),
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F9D8A),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _DetailRow(
                      label: 'Verification',
                      value: _verificationLabel(verificationStatus),
                    ),
                    if (university.isNotEmpty)
                      _DetailRow(label: 'University', value: university),
                    if (email.isNotEmpty)
                      _DetailRow(label: 'Email', value: email),
                    if (phone.isNotEmpty)
                      _DetailRow(label: 'Phone', value: phone),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final provider = context.watch<CarpoolProvider>();

    return StreamBuilder(
      stream: _service.getRequestById(widget.requestId),
      builder: (context, requestSnapshot) {
        if (requestSnapshot.hasError) {
          return Scaffold(appBar: AppBar(title: const Text('Request Details')), body: Center(child: Text(requestSnapshot.error.toString())));
        }
        if (!requestSnapshot.hasData) {
          return Scaffold(appBar: AppBar(title: const Text('Request Details')), body: const Center(child: CircularProgressIndicator()));
        }

        final request = requestSnapshot.data!;
        final isCreator = request.creatorId == currentUid;

        return FutureBuilder(
          future: _service.getGroupByRequestId(widget.requestId),
          builder: (context, groupSnapshot) {
            final group = groupSnapshot.data;
            final isMember = group?.memberIds.contains(currentUid) ?? false;
            final isAdmin = group?.adminId == currentUid;

            return Scaffold(
              appBar: AppBar(
                title: const Text('Request Details'),
                actions: [
                  if (isMember)
                    IconButton(
                      icon: const Icon(Icons.report_problem_outlined, color: Colors.redAccent),
                      onPressed: () {
                        if (group != null) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ReportScreen(requestId: widget.requestId, groupId: group.id)));
                        }
                      },
                    ),
                  if (isCreator)
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () => _showEditSettingsDialog(context, request),
                    ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${request.originLabel} -> ${request.destinationLabel}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              RideStatusBadge(status: request.status),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            DateFormat(
                              'EEE, d MMM • h:mm a',
                            ).format(request.scheduledAt),
                          ),
                          const SizedBox(height: 4),
                          Text('${request.availableSeats} seats available'),
                          const SizedBox(height: 8),
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.directions_car, size: 20, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(request.rideType == CarpoolRideTypes.grab ? 'Grab' : 'Student Driver', style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          if (request.fare != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.payments, size: 20, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text('Estimated Fare: RM ${request.fare!.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          if (isCreator)
                            const Text(
                              'You created this request.',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (isCreator || (group?.driverId == currentUid)) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Management Actions',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (isCreator && request.status == CarpoolRequestStatuses.open)
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: provider.isLoading
                                      ? null
                                      : () => context
                                          .read<CarpoolProvider>()
                                          .updateStatus(
                                            widget.requestId,
                                            CarpoolRequestStatuses.cancelled,
                                          ),
                                  child: const Text('Cancel Request'),
                                ),
                              ),
                            if (((request.rideType == CarpoolRideTypes.grab && isCreator) || (request.rideType == CarpoolRideTypes.studentDriver && group?.driverId == currentUid)) && 
                                (request.status == CarpoolRequestStatuses.open || request.status == CarpoolRequestStatuses.confirmed))
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: provider.isLoading
                                      ? null
                                      : () => context
                                          .read<CarpoolProvider>()
                                          .updateStatus(
                                            widget.requestId,
                                            CarpoolRequestStatuses.inProgress,
                                          ),
                                  child: const Text('Start Ride'),
                                ),
                              ),
                            if (((request.rideType == CarpoolRideTypes.grab && isCreator) || 
                                (request.rideType == CarpoolRideTypes.studentDriver && group?.driverId == currentUid))) ...[
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.payment),
                                  onPressed: () {
                                    _showUpdatePaymentDialog(context, request);
                                  },
                                  label: const Text('Update Payment Info'),
                                ),
                              ),
                              if (request.status == CarpoolRequestStatuses.inProgress)
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _endingRide
                                        ? null
                                        : () async {
                                            if (group == null) return;
                                            
                                            // Fetch member names for the dialog
                                            final names = <String, String>{};
                                            for (final uid in group.memberIds) {
                                              final doc = await FirebaseFirestore.instance.collection(AppCollections.users).doc(uid).get();
                                              final name = doc.data()?[AppFields.userFullName] as String?;
                                              names[uid] = (name != null && name.trim().isNotEmpty) ? name.trim() : uid;
                                            }

                                            if (!mounted) return;
                                            final success = await showDialog<bool>(
                                              context: context,
                                              barrierDismissible: false,
                                              builder: (_) => EndRideSplitDialog(
                                                request: request,
                                                group: group,
                                                memberNames: names,
                                              ),
                                            );

                                            if (success == true && mounted) {
                                              setState(() => _endingRide = true);
                                              try {
                                                await _service.updateRequestStatus(
                                                  widget.requestId,
                                                  CarpoolRequestStatuses.completed,
                                                );
                                                if (mounted) {
                                                  setState(() => _didEndRide = true);
                                                }
                                              } catch (e) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                                                }
                                              } finally {
                                                if (mounted) setState(() => _endingRide = false);
                                              }
                                            }
                                          },
                                    child: _endingRide
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('End Ride'),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (!isCreator && !isMember)
                    StreamBuilder<CarpoolApplicantModel?>(
                      stream: _service.getUserApplication(
                        widget.requestId,
                        currentUid,
                      ),
                      builder: (context, myApplicationSnapshot) {
                        final myApplication = myApplicationSnapshot.data;
                        final hasAppliedPassenger =
                            myApplication?.applicantRole ==
                                CarpoolApplicantRoles.passenger ||
                            _justAppliedPassenger;
                        final hasAppliedDriver =
                            myApplication?.applicantRole ==
                                CarpoolApplicantRoles.driver ||
                            _justAppliedDriver;
                        final passengerAccepted =
                            hasAppliedPassenger &&
                            myApplication?.status ==
                                CarpoolApplicantStatuses.accepted;
                        final driverAccepted =
                            hasAppliedDriver &&
                            myApplication?.status ==
                                CarpoolApplicantStatuses.accepted;
                        final hasAnyState =
                            isMember || passengerAccepted || driverAccepted;
                        final canApplyHere =
                            !provider.hasActiveCarpool || hasAnyState;

                        String passengerLabel;
                        VoidCallback? onPassengerPressed;

                        if (isMember || passengerAccepted) {
                          passengerLabel = 'Joined';
                          onPassengerPressed = null;
                        } else if (hasAppliedPassenger) {
                          if (myApplication == null) {
                            passengerLabel = 'Applying...';
                            onPassengerPressed = null;
                          } else {
                            passengerLabel = 'Cancel Passenger Application';
                            onPassengerPressed = () async {
                              try {
                                await context.read<CarpoolProvider>().withdrawApplication(myApplication.id);
                                if (mounted) setState(() => _justAppliedPassenger = false);
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                              }
                            };
                          }
                        } else if (!canApplyHere) {
                          passengerLabel = request.joinMode == CarpoolJoinModes.open
                              ? 'Join as Passenger'
                              : 'Apply as Passenger';
                          onPassengerPressed = () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('You are already in an active carpool. Leave it before applying.'),
                              ),
                            );
                          };
                        } else {
                          passengerLabel = request.joinMode == CarpoolJoinModes.open
                              ? 'Join as Passenger'
                              : 'Apply as Passenger';
                          onPassengerPressed = () async {
                            try {
                              await context.read<CarpoolProvider>().applyToRequest(
                                widget.requestId,
                                currentUid,
                                CarpoolApplicantRoles.passenger,
                              );
                              if (mounted) setState(() => _justAppliedPassenger = true);
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                            }
                          };
                        }

                        String driverLabel;
                        VoidCallback? onDriverPressed;

                        if (driverAccepted) {
                          driverLabel = 'Accepted as Driver';
                          onDriverPressed = null;
                        } else if (hasAppliedDriver) {
                          if (myApplication == null) {
                            driverLabel = 'Applying...';
                            onDriverPressed = null;
                          } else {
                            driverLabel = 'Cancel Driver Application';
                            onDriverPressed = () async {
                              try {
                                await context.read<CarpoolProvider>().withdrawApplication(myApplication.id);
                                if (mounted) setState(() => _justAppliedDriver = false);
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                              }
                            };
                          }
                        } else if (!canApplyHere) {
                          driverLabel = 'Apply as Driver';
                          onDriverPressed = () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('You are already in an active carpool. Leave it before applying.'),
                              ),
                            );
                          };
                        } else {
                          driverLabel = 'Apply as Driver';
                          onDriverPressed = () async {
                            try {
                              await context.read<CarpoolProvider>().applyToRequest(
                                widget.requestId,
                                currentUid,
                                CarpoolApplicantRoles.driver,
                              );
                              if (mounted) setState(() => _justAppliedDriver = true);
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                            }
                          };
                        }

                        return Column(
                          children: [
                            FilledButton(
                              onPressed: onPassengerPressed,
                              child: Text(passengerLabel),
                            ),
                            if (request.rideType != CarpoolRideTypes.grab) ...[
                              const SizedBox(height: 8),
                              OutlinedButton(
                                onPressed: onDriverPressed,
                                child: Text(driverLabel),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  if (group != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Members',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (final memberId in group.memberIds)
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(memberId)
                            .get(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox.shrink();
                          final data =
                              snapshot.data!.data() as Map<String, dynamic>?;
                          final name =
                              data?['fullName'] ??
                              data?['displayName'] ??
                              memberId;
                          final verified = data?['verified'] == true;
                          final roleLabel = memberId == group.adminId
                              ? 'Creator'
                              : memberId == group.driverId
                                  ? 'Driver'
                                  : 'Passenger';
                          return ListTile(
                            tileColor: Colors.white,
                            splashColor: const Color(0x11000000),
                            leading: CircleAvatar(child: Text(_initials(name))),
                            title: Text(name),
                            subtitle: Text(
                              verified ? '$roleLabel • Verified' : roleLabel,
                            ),
                            trailing: isCreator && memberId != currentUid
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.person_remove,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: provider.isLoading
                                        ? null
                                        : () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text(
                                                  'Remove Member',
                                                ),
                                                content: const Text(
                                                  'Remove this member from the ride?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          ctx,
                                                          false,
                                                        ),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          ctx,
                                                          true,
                                                        ),
                                                    child: const Text('Remove'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm != true) return;
                                            try {
                                              await context
                                                  .read<CarpoolProvider>()
                                                  .kickMember(
                                                    widget.requestId,
                                                    memberId,
                                                  );
                                            } catch (e) {
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(e.toString()),
                                                ),
                                              );
                                            }
                                          },
                                  )
                                : null,
                            onTap: () => _showApplicantDetails(memberId),
                          );
                        },
                      ),
                    if (!isAdmin)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.exit_to_app),
                          label: const Text('Leave Ride'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                          ),
                          onPressed: provider.isLoading
                              ? null
                              : () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Leave Ride'),
                                      content: const Text(
                                        'Are you sure you want to leave this ride?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Leave'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm != true) return;
                                  try {
                                    await provider.leaveGroup(widget.requestId);
                                    if (mounted) Navigator.of(context).pop();
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.toString())),
                                    );
                                  }
                                },
                        ),
                      ),
                  ],
                  if (isCreator) ...[
                    const Text(
                      'Applicants',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<CarpoolApplicantModel>>(
                      stream: _service.getApplicants(widget.requestId),
                      builder: (context, applicantSnapshot) {
                        if (applicantSnapshot.hasError) {
                          return Center(
                            child: Text(
                              'Failed to load applicants: ${applicantSnapshot.error}',
                            ),
                          );
                        }
                        if (!applicantSnapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final applicants = applicantSnapshot.data!;
                        if (applicants.isEmpty) {
                          return const Text('No applicants yet.');
                        }
                        return Column(
                          children: applicants.map((applicant) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ApplicantCard(
                                applicant: applicant,
                                onTap: () =>
                                    _showApplicantDetails(applicant.userId),
                                onAccept: () => context
                                    .read<CarpoolProvider>()
                                    .acceptApplicant(
                                      widget.requestId,
                                      applicant.id,
                                      applicant.applicantRole,
                                    ),
                                onReject: () => context
                                    .read<CarpoolProvider>()
                                    .rejectApplicant(
                                      widget.requestId,
                                      applicant.id,
                                    ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                  if (isMember) ...[
                    const SizedBox(height: 16),
                    if (request.status == CarpoolRequestStatuses.completed) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PaymentScreen(requestId: widget.requestId),
                              ),
                            );
                          },
                          icon: const Icon(Icons.payment),
                          label: const Text('View Payment'),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: group == null
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GroupChatScreen(
                                    requestId: widget.requestId,
                                    groupId: group.id,
                                  ),
                                ),
                              ),
                        child: const Text('Open Group Chat'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts.first.isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (parts.isNotEmpty && parts.first.isNotEmpty) {
      return parts.first[0].toUpperCase();
    }
    return '?';
  }

  String _verificationLabel(String status) {
    return switch (status) {
      'approved' || 'verified_driver' => 'Verified',
      'pending' => 'Pending verification',
      'rejected' => 'Verification rejected',
      _ => 'Not verified',
    };
  }

  void _showUpdatePaymentDialog(BuildContext context, CarpoolRequestModel request) async {
    final paymentService = PaymentService();
    final payment = await paymentService.getPayment(request.id);
    if (payment == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No payment profile exists yet. Wait for a passenger to join or recreate the request.')));
      }
      return;
    }
    
    if (!context.mounted) return;
    
    String qrCodeUrl = payment.qrCodeUrl;
    final bankNameController = TextEditingController(text: payment.bankName);
    final accountNumberController = TextEditingController(text: payment.accountNumber);
    final accountNameController = TextEditingController(text: payment.accountName);
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Update Payment Settings'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(controller: bankNameController, decoration: const InputDecoration(labelText: 'Bank Name')),
                    const SizedBox(height: 8),
                    TextField(controller: accountNumberController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Account Number')),
                    const SizedBox(height: 8),
                    TextField(controller: accountNameController, decoration: const InputDecoration(labelText: 'Account Holder Name')),
                    const SizedBox(height: 16),
                    const Text('QR Code URL'),
                    if (qrCodeUrl.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            Image.network(qrCodeUrl, height: 60),
                            IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => qrCodeUrl = '')),
                          ],
                        ),
                      )
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                FilledButton(
                  onPressed: saving ? null : () async {
                    setState(() => saving = true);
                    try {
                      await context.read<PaymentProvider>().updatePaymentSettings(
                        payment.id,
                        qrCodeUrl,
                        bankNameController.text.trim(),
                        accountNumberController.text.trim(),
                        accountNameController.text.trim(),
                      );
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                    } finally {
                      if (mounted) setState(() => saving = false);
                    }
                  },
                  child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _showEditSettingsDialog(BuildContext context, CarpoolRequestModel request) {
    showDialog(
      context: context,
      builder: (_) => _EditSettingsDialog(request: request),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditSettingsDialog extends StatefulWidget {
  const _EditSettingsDialog({required this.request});
  final CarpoolRequestModel request;

  @override
  State<_EditSettingsDialog> createState() => _EditSettingsDialogState();
}

class _EditSettingsDialogState extends State<_EditSettingsDialog> {
  late String _rideType;
  late String _joinMode;
  late DateTime _scheduledAt;
  final _fareController = TextEditingController();
  
  CarpoolGroupModel? _group;
  String? _newCreatorId;
  bool _loadingGroup = true;
  Map<String, String> _memberNames = {};

  @override
  void initState() {
    super.initState();
    _rideType = widget.request.rideType;
    _joinMode = widget.request.joinMode;
    _scheduledAt = widget.request.scheduledAt;
    _fareController.text = widget.request.fare?.toString() ?? '';
    _newCreatorId = widget.request.creatorId;
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    try {
      final group = await CarpoolService().getGroupByRequestId(widget.request.id);
      if (group != null) {
        _group = group;
        // Fetch member names
        final names = <String, String>{};
        for (final uid in group.memberIds) {
          final doc = await FirebaseFirestore.instance.collection(AppCollections.users).doc(uid).get();
          if (doc.exists) {
            final data = doc.data();
            final name = (data?[AppFields.userFullName] as String?)?.trim();
            if (name != null && name.isNotEmpty) {
              names[uid] = name;
            } else {
              names[uid] = uid; // fallback
            }
          } else {
            names[uid] = uid;
          }
        }
        if (mounted) {
          setState(() {
            _memberNames = names;
            _loadingGroup = false;
          });
        }
      } else {
        if (mounted) setState(() => _loadingGroup = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingGroup = false);
    }
  }

  @override
  void dispose() {
    _fareController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time != null) {
      setState(() {
        _scheduledAt = DateTime(
          _scheduledAt.year,
          _scheduledAt.month,
          _scheduledAt.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) {
      setState(() {
        _scheduledAt = DateTime(
          date.year,
          date.month,
          date.day,
          _scheduledAt.hour,
          _scheduledAt.minute,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Request Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _rideType,
              decoration: const InputDecoration(labelText: 'Ride Type'),
              items: const [
                DropdownMenuItem(value: CarpoolRideTypes.studentDriver, child: Text('Student Driver')),
                DropdownMenuItem(value: CarpoolRideTypes.grab, child: Text('Grab')),
              ],
              onChanged: (val) => setState(() => _rideType = val!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _joinMode,
              decoration: const InputDecoration(labelText: 'Join Mode'),
              items: const [
                DropdownMenuItem(value: CarpoolJoinModes.approval, child: Text('Requires Approval')),
                DropdownMenuItem(value: CarpoolJoinModes.open, child: Text('Open Join')),
              ],
              onChanged: (val) => setState(() => _joinMode = val!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _fareController,
              decoration: const InputDecoration(
                labelText: 'Estimated Fare (RM)',
                hintText: 'e.g. 5.00',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            Text('Scheduled At: ${DateFormat('EEE, d MMM • h:mm a').format(_scheduledAt)}'),
            Row(
              children: [
                TextButton(onPressed: _pickDate, child: const Text('Change Date')),
                TextButton(onPressed: _pickTime, child: const Text('Change Time')),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            if (_loadingGroup)
              const Center(child: CircularProgressIndicator())
            else if (_group != null && _group!.memberIds.length > 1) ...[
              const Text('Transfer Creator Role', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _newCreatorId,
                decoration: const InputDecoration(labelText: 'Select New Creator'),
                items: _group!.memberIds.map((uid) {
                  return DropdownMenuItem(
                    value: uid,
                    child: Text(_memberNames[uid] ?? uid),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _newCreatorId = val),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final fareText = _fareController.text.trim();
            final fare = double.tryParse(fareText);
            final updates = <String, dynamic>{
              AppFields.rideType: _rideType,
              AppFields.joinMode: _joinMode,
              AppFields.scheduledAt: Timestamp.fromDate(_scheduledAt),
            };
            if (fareText.isEmpty) {
              updates[AppFields.fare] = FieldValue.delete();
            } else if (fare != null) {
              updates[AppFields.fare] = fare;
            }
            
            try {
              await context.read<CarpoolProvider>().updateRequestSettings(widget.request.id, updates);
              if (_newCreatorId != null && _newCreatorId != widget.request.creatorId) {
                await context.read<CarpoolProvider>().transferCreator(widget.request.id, _newCreatorId!);
              }
              if (mounted) Navigator.pop(context);
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
