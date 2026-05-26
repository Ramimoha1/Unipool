import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:unipool/core/constants.dart';
import '../models/carpool_applicant_model.dart';
import '../providers/carpool_provider.dart';
import '../services/carpool_service.dart';
import '../widgets/applicant_card.dart';
import '../widgets/ride_status_badge.dart';
import 'group_chat_screen.dart';

class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final _service = CarpoolService();

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

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
                              Expanded(child: Text('${request.originLabel} -> ${request.destinationLabel}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                              RideStatusBadge(status: request.status),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(DateFormat('EEE, d MMM • h:mm a').format(request.scheduledAt)),
                          const SizedBox(height: 4),
                          Text('${request.availableSeats} seats available'),
                          const SizedBox(height: 16),
                          if (isCreator)
                            const Text('You created this request.', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!isCreator)
                    Column(
                      children: [
                        FilledButton(
                          onPressed: () => context.read<CarpoolProvider>().applyToRequest(widget.requestId, currentUid, CarpoolApplicantRoles.passenger),
                          child: const Text('Join as Passenger'),
                        ),
                        if (request.rideType != CarpoolRideTypes.grab) ...[
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () => context.read<CarpoolProvider>().applyToRequest(widget.requestId, currentUid, CarpoolApplicantRoles.driver),
                            child: const Text('Apply as Driver'),
                          ),
                        ],
                      ],
                    ),
                  if (isCreator) ...[
                    const Text('Applicants', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    StreamBuilder<List<CarpoolApplicantModel>>(
                      stream: _service.getApplicants(widget.requestId),
                      builder: (context, applicantSnapshot) {
                        if (!applicantSnapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
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
                                onAccept: () => context.read<CarpoolProvider>().acceptApplicant(widget.requestId, applicant.id, applicant.applicantRole),
                                onReject: () => context.read<CarpoolProvider>().rejectApplicant(widget.requestId, applicant.id),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    if (request.status == CarpoolRequestStatuses.open)
                      OutlinedButton(
                        onPressed: () => context.read<CarpoolProvider>().updateStatus(widget.requestId, CarpoolRequestStatuses.cancelled),
                        child: const Text('Cancel Request'),
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
}