import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  List<XFile> _attachments = [];
  bool _isSubmitting = false;
  Map<String, String> _userNames = {};
  bool _loadingNames = true;
  List<String>? _reportableUsers;

  @override
  void initState() {
    super.initState();
    _loadGroupAndNames();
  }

  Future<void> _loadGroupAndNames() async {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final group = await _service.getGroupByRequestId(widget.requestId);
    if (group == null || !mounted) return;

    final users = group.memberIds.where((u) => u != currentUid).toList();
    _reportableUsers = users;

    final names = <String, String>{};
    for (final u in users) {
      final doc = await FirebaseFirestore.instance.collection(AppCollections.users).doc(u).get();
      names[u] = doc.data()?[AppFields.userFullName] as String? ?? u;
    }

    if (mounted) {
      setState(() {
        _userNames = names;
        _loadingNames = false;
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _attachments.addAll(picked);
      });
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (_targetUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please choose a user to report.')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentUid = FirebaseAuth.instance.currentUser!.uid;
      final reportRef = FirebaseFirestore.instance.collection(AppCollections.rideReports).doc();
      final reportId = reportRef.id;

      // 1. Upload attachments
      final List<String> attachmentUrls = [];
      for (final file in _attachments) {
        final ext = file.name.split('.').last.toLowerCase();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final storageRef = FirebaseStorage.instance.ref().child('ride_reports_attachments/$reportId/$fileName');
        
        final bytes = await file.readAsBytes();
        await storageRef.putData(bytes, SettableMetadata(contentType: file.mimeType ?? 'image/jpeg'));
        final url = await storageRef.getDownloadURL();
        attachmentUrls.add(url);
      }

      // 2. Fetch Chat Snapshot
      final chatDocs = await FirebaseFirestore.instance
          .collection(AppCollections.carpoolGroups)
          .doc(widget.groupId)
          .collection('messages')
          .orderBy('sent_at', descending: false)
          .get();

      final List<Map<String, dynamic>> chatSnapshot = chatDocs.docs.map((d) {
        final data = d.data();
        if (data['sent_at'] is Timestamp) {
          // Convert timestamp to string for safe JSON embedding
          data['sent_at'] = (data['sent_at'] as Timestamp).toDate().toIso8601String();
        }
        return data;
      }).toList();

      // 3. Save report manually (we bypass the old service method to use our ID and avoid duplicate writes)
      await reportRef.set({
        AppFields.requestId: widget.requestId,
        AppFields.reportedBy: currentUid,
        AppFields.targetUserId: _targetUserId,
        AppFields.reason: _reason,
        AppFields.description: _descriptionController.text.trim(),
        AppFields.status: CarpoolReportStatuses.open,
        AppFields.createdAt: FieldValue.serverTimestamp(),
        AppFields.attachmentUrls: attachmentUrls,
        AppFields.chatSnapshot: chatSnapshot,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted successfully.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit report: $e')));
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Issue')),
      body: _loadingNames
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Choose a user to report', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_reportableUsers == null || _reportableUsers!.isEmpty)
                  const Text('No other users to report.')
                else
                  ..._reportableUsers!.map((userId) {
                    final selected = _targetUserId == userId;
                    final name = _userNames[userId] ?? userId;
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
                              Expanded(child: Text(name)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 16),
                const Text('Reason', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  decoration: const InputDecoration(labelText: 'Description (Optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                const Text('Attachments', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._attachments.asMap().entries.map((e) {
                      final i = e.key;
                      final file = e.value;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                              image: DecorationImage(
                                image: FileImage(File(file.path)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            right: -8,
                            top: -8,
                            child: InkWell(
                              onTap: () => _removeAttachment(i),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                    InkWell(
                      onTap: _pickImages,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF0F9D8A)),
                          color: const Color(0xFFE8F7F5),
                        ),
                        child: const Icon(Icons.add_photo_alternate, color: Color(0xFF0F9D8A), size: 32),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F9D8A)),
                    child: _isSubmitting
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Submit Report', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}