import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:unipool/core/constants.dart';
import '../services/carpool_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, required this.requestId, required this.groupId});

  final String requestId;
  final String groupId;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _service = CarpoolService();
  final _descriptionController = TextEditingController();
  String? _targetUserId;
  String _reason = CarpoolReportReasons.didNotPay;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_targetUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please choose a user to report.')));
      return;
    }

    await _service.createReport(
      requestId: widget.requestId,
      reportedBy: FirebaseAuth.instance.currentUser!.uid,
      targetUserId: _targetUserId!,
      reason: _reason,
      description: _descriptionController.text.trim(),
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Report Issue')),
      body: FutureBuilder(
        future: _service.getGroupByRequestId(widget.requestId),
        builder: (context, groupSnapshot) {
          final group = groupSnapshot.data;
          final reportableUsers = (group?.memberIds ?? const []).where((userId) => userId != currentUid).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Choose a user to report'),
              const SizedBox(height: 8),
              ...reportableUsers.map((userId) {
                final selected = _targetUserId == userId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _targetUserId = userId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? const Color(0xFF0F9D8A) : const Color(0xFFD9E2EC)),
                        color: selected ? const Color(0xFFE8F7F5) : Colors.white,
                      ),
                      child: Row(
                        children: [
                          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? const Color(0xFF0F9D8A) : Colors.grey),
                          const SizedBox(width: 12),
                          Expanded(child: Text(userId)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              const Text('Reason'),
              const SizedBox(height: 8),
              ...[
                (CarpoolReportReasons.didNotPay, 'Did not pay'),
                (CarpoolReportReasons.unsafeDriver, 'Unsafe driver'),
                (CarpoolReportReasons.noShow, 'No show'),
                (CarpoolReportReasons.other, 'Other'),
              ].map((option) {
                final selected = _reason == option.$1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _reason = option.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? const Color(0xFF0F9D8A) : const Color(0xFFD9E2EC)),
                        color: selected ? const Color(0xFFE8F7F5) : Colors.white,
                      ),
                      child: Row(
                        children: [
                          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? const Color(0xFF0F9D8A) : Colors.grey),
                          const SizedBox(width: 12),
                          Expanded(child: Text(option.$2)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _submit, child: const Text('Submit Report')),
            ],
          );
        },
      ),
    );
  }
}