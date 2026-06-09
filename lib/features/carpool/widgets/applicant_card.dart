import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:unipool/core/constants.dart';
import '../models/carpool_applicant_model.dart';

class ApplicantCard extends StatefulWidget {
  const ApplicantCard({super.key, required this.applicant, required this.onAccept, required this.onReject, this.onTap});

  final CarpoolApplicantModel applicant;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback? onTap;

  @override
  State<ApplicantCard> createState() => _ApplicantCardState();
}

class _ApplicantCardState extends State<ApplicantCard> {
  late final Future<DocumentSnapshot<Map<String, dynamic>>> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = FirebaseFirestore.instance.collection(AppCollections.users).doc(widget.applicant.userId).get();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _userFuture,
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() ?? const <String, dynamic>{};
        final displayName = _displayName(userData);
        final verificationStatus = (userData[AppFields.userVerificationStatus] as String?) ?? 'unverified';
        final university = (userData['university'] as String?)?.trim() ?? '';
        final roleLabel = widget.applicant.applicantRole == CarpoolApplicantRoles.driver ? 'Driver applicant' : 'Passenger applicant';
        final initials = _initials(displayName);
        final isPending = widget.applicant.status == CarpoolApplicantStatuses.pending;
        final statusLabel = widget.applicant.status.toUpperCase();
        final statusColor = switch (widget.applicant.status) {
          CarpoolApplicantStatuses.accepted => const Color(0xFF1A9B8A),
          CarpoolApplicantStatuses.rejected => const Color(0xFFE53935),
          _ => const Color(0xFFF59E0B),
        };

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFFE8F7F5),
                    child: Text(
                      initials,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F9D8A)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayName,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                            ),
                            _StatusChip(label: statusLabel, color: statusColor),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(roleLabel, style: const TextStyle(color: Colors.black54)),
                        if (university.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(university, style: const TextStyle(color: Colors.black54)),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _VerificationChip(status: verificationStatus),
                            const SizedBox(width: 8),
                            Text(
                              isPending ? 'Tap for details' : 'Application ${widget.applicant.status}',
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isPending) ...[
                    IconButton(onPressed: widget.onReject, icon: const Icon(Icons.close, color: Colors.red)),
                    IconButton(onPressed: widget.onAccept, icon: const Icon(Icons.check, color: Colors.green)),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _displayName(Map<String, dynamic> userData) {
    final fullName = (userData[AppFields.userFullName] as String?)?.trim();
    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }

    final displayName = (userData['displayName'] as String?)?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    return widget.applicant.userId.isNotEmpty ? widget.applicant.userId : 'Unknown user';
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
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _VerificationChip extends StatelessWidget {
  const _VerificationChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'approved' || 'verified_driver' => ('Verified', const Color(0xFF1A9B8A)),
      'pending' => ('Pending verification', const Color(0xFFF59E0B)),
      'rejected' => ('Verification rejected', const Color(0xFFE53935)),
      _ => ('Not verified', const Color(0xFF6B7280)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
