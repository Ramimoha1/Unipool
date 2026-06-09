import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:unipool/core/constants.dart';
import '../models/carpool_applicant_model.dart';
import '../providers/carpool_provider.dart';
import '../services/carpool_service.dart';
import '../services/payment_service.dart';
import '../widgets/applicant_card.dart';
import '../widgets/ride_status_badge.dart';
import 'group_chat_screen.dart';
import 'payment_screen.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Request Details')),
      body: StreamBuilder(
        stream: _service.getRequestById(widget.requestId),
        builder: (context, requestSnapshot) {
          if (requestSnapshot.hasError) {
            return Center(child: Text(requestSnapshot.error.toString()));
          }
          if (!requestSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final request = requestSnapshot.data!;
          final isCreator = request.creatorId == currentUid;

          return FutureBuilder(
            future: _service.getGroupByRequestId(widget.requestId),
            builder: (context, groupSnapshot) {
              final group = groupSnapshot.data;
              final isMember = group?.memberIds.contains(currentUid) ?? false;
              final isAdmin = group?.adminId == currentUid;

              return ListView(
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
                  if (isCreator) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Creator Actions',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (request.status == CarpoolRequestStatuses.open)
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
                            if (request.status == CarpoolRequestStatuses.confirmed)
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
                            if (request.status == CarpoolRequestStatuses.inProgress)
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _endingRide
                                      ? null
                                      : () async {
                                          setState(() => _endingRide = true);
                                          try {
                                            await _paymentService.triggerPayment(
                                              widget.requestId,
                                            );
                                            await _service.updateRequestStatus(
                                              widget.requestId,
                                              CarpoolRequestStatuses.completed,
                                            );
                                            if (!mounted) return;
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => PaymentScreen(
                                                  requestId: widget.requestId,
                                                ),
                                              ),
                                            );
                                          } catch (e) {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(content: Text(e.toString())),
                                            );
                                          } finally {
                                            if (mounted) {
                                              setState(() => _endingRide = false);
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
                        if (isMember || passengerAccepted) {
                          passengerLabel = 'Joined';
                        } else if (hasAppliedPassenger) {
                          passengerLabel = 'Applied';
                        } else {
                          passengerLabel =
                              request.joinMode == CarpoolJoinModes.open
                              ? 'Join as Passenger'
                              : 'Apply as Passenger';
                        }

                        VoidCallback? onPassengerPressed;
                        if (isMember || hasAppliedPassenger) {
                          onPassengerPressed = null;
                        } else if (!canApplyHere) {
                          onPassengerPressed = () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'You are already in an active carpool. Leave it before applying.',
                                ),
                              ),
                            );
                          };
                        } else {
                          onPassengerPressed = () async {
                            try {
                              await context
                                  .read<CarpoolProvider>()
                                  .applyToRequest(
                                    widget.requestId,
                                    currentUid,
                                    CarpoolApplicantRoles.passenger,
                                  );
                              if (mounted) {
                                setState(() => _justAppliedPassenger = true);
                              }
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          };
                        }

                        VoidCallback? onDriverPressed;
                        if (hasAppliedDriver || driverAccepted) {
                          onDriverPressed = null;
                        } else if (!canApplyHere) {
                          onDriverPressed = () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'You are already in an active carpool. Leave it before applying.',
                                ),
                              ),
                            );
                          };
                        } else {
                          onDriverPressed = () async {
                            try {
                              await context
                                  .read<CarpoolProvider>()
                                  .applyToRequest(
                                    widget.requestId,
                                    currentUid,
                                    CarpoolApplicantRoles.driver,
                                  );
                              if (mounted) {
                                setState(() => _justAppliedDriver = true);
                              }
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
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
                                child: Text(
                                  (hasAppliedDriver || driverAccepted)
                                      ? 'Applied as Driver'
                                      : 'Apply as Driver',
                                ),
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
                    FilledButton(
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
                  ],
                ],
              );
            },
          );
        },
      ),
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
