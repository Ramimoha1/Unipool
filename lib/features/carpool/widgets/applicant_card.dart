import 'package:flutter/material.dart';
import '../models/carpool_applicant_model.dart';

class ApplicantCard extends StatelessWidget {
  const ApplicantCard({super.key, required this.applicant, required this.onAccept, required this.onReject});

  final CarpoolApplicantModel applicant;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(child: Text(applicant.userId.isNotEmpty ? applicant.userId[0].toUpperCase() : '?')),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(applicant.userId, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('${applicant.applicantRole} • ${applicant.status}'),
                ],
              ),
            ),
            IconButton(onPressed: onReject, icon: const Icon(Icons.close, color: Colors.red)),
            IconButton(onPressed: onAccept, icon: const Icon(Icons.check, color: Colors.green)),
          ],
        ),
      ),
    );
  }
}