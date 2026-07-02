import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:unipool/core/constants.dart';
import 'package:unipool/features/carpool/models/ride_report_model.dart';

class AdminReportDetailScreen extends StatefulWidget {
  const AdminReportDetailScreen({super.key, required this.report});
  final RideReportModel report;

  @override
  State<AdminReportDetailScreen> createState() => _AdminReportDetailScreenState();
}

class _AdminReportDetailScreenState extends State<AdminReportDetailScreen> {
  bool _isProcessing = false;
  String _reporterName = '';
  String _targetName = '';

  @override
  void initState() {
    super.initState();
    _loadNames();
  }

  Future<void> _loadNames() async {
    final reporterDoc = await FirebaseFirestore.instance.collection(AppCollections.users).doc(widget.report.reportedBy).get();
    final targetDoc = await FirebaseFirestore.instance.collection(AppCollections.users).doc(widget.report.targetUserId).get();

    if (mounted) {
      setState(() {
        _reporterName = reporterDoc.data()?[AppFields.userFullName] ?? widget.report.reportedBy;
        _targetName = targetDoc.data()?[AppFields.userFullName] ?? widget.report.targetUserId;
      });
    }
  }

  Future<void> _updateReportStatus(String status) async {
    await FirebaseFirestore.instance.collection(AppCollections.rideReports).doc(widget.report.id).update({
      AppFields.status: status,
    });
  }

  Future<void> _banUser(String banType, String reason, {DateTime? expiryDate}) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    await FirebaseFirestore.instance.collection(AppCollections.users).doc(widget.report.targetUserId).update({
      'isBanned': true,
      'isActive': false,
      'banType': banType,
      AppFields.userBannedStatus: banType,
      AppFields.userBannedReason: reason,
      'banReason': reason,
      'banExpiresAt': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
      'bannedAt': FieldValue.serverTimestamp(),
      'bannedBy': adminUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _showBanDialog(BuildContext context) {
    final reasonCtrl = TextEditingController(text: 'Violated terms: ${widget.report.reason}');
    String selectedBanType = 'temporary';
    DateTime? expiryDate = DateTime.now().add(const Duration(days: 3));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Accept Report & Ban User', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ban Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedBanType,
                  items: const [
                    DropdownMenuItem(value: 'temporary', child: Text('Temporary Suspension')),
                    DropdownMenuItem(value: 'until_payment', child: Text('Suspend until Payment')),
                    DropdownMenuItem(value: 'permanent', child: Text('Permanent Ban')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDlgState(() {
                        selectedBanType = val;
                        if (val == 'temporary') {
                          expiryDate ??= DateTime.now().add(const Duration(days: 3));
                        } else {
                          expiryDate = null;
                        }
                      });
                    }
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Reason *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Describe the violation…',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                if (selectedBanType == 'temporary') ...[
                  const SizedBox(height: 16),
                  const Text('Suspension ends on *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: expiryDate ?? DateTime.now().add(const Duration(days: 3)),
                        firstDate: DateTime.now().add(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDlgState(() => expiryDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF6B7280)),
                          const SizedBox(width: 10),
                          Text(
                            expiryDate != null
                                ? '${expiryDate!.year}-${expiryDate!.month.toString().padLeft(2, '0')}-${expiryDate!.day.toString().padLeft(2, '0')}'
                                : 'Pick a date',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
            ),
            ElevatedButton(
              onPressed: () async {
                final reason = reasonCtrl.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a reason.')));
                  return;
                }
                if (selectedBanType == 'temporary' && expiryDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please pick an expiry date.')));
                  return;
                }
                Navigator.pop(ctx);
                
                setState(() => _isProcessing = true);
                try {
                  await _banUser(selectedBanType, reason, expiryDate: expiryDate);
                  await _updateReportStatus('accepted');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User banned successfully.')));
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    setState(() => _isProcessing = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Apply Ban'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(String action) async {
    setState(() => _isProcessing = true);
    try {
      if (action == 'reject') {
        await _updateReportStatus('rejected');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report rejected successfully.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isProcessing = false);
      }
    }
  }

  Widget _buildChatLog() {
    final chats = widget.report.chatSnapshot;
    if (chats.isEmpty) {
      return const Text('No chat logs available.', style: TextStyle(color: Colors.grey));
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      height: 250,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: chats.length,
        itemBuilder: (context, index) {
          final msg = chats[index];
          final sender = msg['sender_name'] ?? 'Unknown';
          final content = msg['content'] ?? '';
          final timeStr = msg['sent_at'] as String?;
          final time = timeStr != null ? DateFormat('HH:mm').format(DateTime.parse(timeStr)) : '';
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('[$time] ', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text('$sender: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Expanded(child: Text(content, style: const TextStyle(fontSize: 13))),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Detail')),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reason: ${widget.report.reason}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Reporter: $_reporterName'),
                        Text('Reported User: $_targetName'),
                        Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(widget.report.createdAt)}'),
                        const Divider(),
                        const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(widget.report.description.isEmpty ? 'No description provided.' : widget.report.description),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Attachments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (widget.report.attachmentUrls.isEmpty)
                  const Text('No attachments provided.', style: TextStyle(color: Colors.grey))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.report.attachmentUrls.map((url) {
                      return InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => Dialog(
                              child: InteractiveViewer(
                                child: Image.network(url),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 16),
                const Text('Chat Log (At Time of Report)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildChatLog(),
                const SizedBox(height: 24),
                const Text('Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.grey),
                  onPressed: () => _handleAction('reject'),
                  icon: const Icon(Icons.close),
                  label: const Text('Reject Report'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
                  onPressed: () => _showBanDialog(context),
                  icon: const Icon(Icons.block),
                  label: const Text('Accept & Ban User'),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
