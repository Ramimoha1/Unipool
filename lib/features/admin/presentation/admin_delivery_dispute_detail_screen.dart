import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:unipool/core/constants.dart';
import 'package:unipool/features/delivery/models/delivery_dispute_model.dart';
import 'package:unipool/features/delivery/services/delivery_dispute_service.dart';

class AdminDeliveryDisputeDetailScreen extends StatefulWidget {
  const AdminDeliveryDisputeDetailScreen({super.key, required this.dispute});

  final DeliveryDisputeModel dispute;

  @override
  State<AdminDeliveryDisputeDetailScreen> createState() =>
      _AdminDeliveryDisputeDetailScreenState();
}

class _AdminDeliveryDisputeDetailScreenState
    extends State<AdminDeliveryDisputeDetailScreen> {
  bool _isLoading = true;
  bool _isProcessing = false;

  String _jobTitle = 'Loading...';
  String _jobStatus = 'Loading...';
  String _reporterName = '';
  String _reporterEmail = '';
  String _accusedName = '';
  String _accusedEmail = '';
  String _accusedId = '';

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final db = FirebaseFirestore.instance;

      // 1. Fetch Job
      final jobDoc = await db
          .collection(AppCollections.deliveryJobs)
          .doc(widget.dispute.jobId)
          .get();
      final jobData = jobDoc.data();
      if (jobData != null) {
        _jobTitle = jobData[AppFields.title] as String? ?? 'Untitled Job';
        _jobStatus = jobData[AppFields.jobStatus] as String? ?? 'Unknown';
      } else {
        _jobTitle = 'Job not found (deleted)';
        _jobStatus = 'N/A';
      }

      // 2. Fetch Users
      final reporterUid = widget.dispute.filedBy;
      _accusedId = reporterUid == widget.dispute.sellerId
          ? widget.dispute.driverId
          : widget.dispute.sellerId;

      final reporterDoc =
          await db.collection(AppCollections.users).doc(reporterUid).get();
      final accusedDoc =
          await db.collection(AppCollections.users).doc(_accusedId).get();

      final reporterData = reporterDoc.data();
      final accusedData = accusedDoc.data();

      if (reporterData != null) {
        _reporterName =
            reporterData[AppFields.userFullName] as String? ?? reporterUid;
        _reporterEmail =
            reporterData[AppFields.userEmail] as String? ?? 'No email';
      } else {
        _reporterName = reporterUid;
        _reporterEmail = 'Unknown';
      }

      if (accusedData != null) {
        _accusedName =
            accusedData[AppFields.userFullName] as String? ?? _accusedId;
        _accusedEmail =
            accusedData[AppFields.userEmail] as String? ?? 'No email';
      } else {
        _accusedName = _accusedId;
        _accusedEmail = 'Unknown';
      }
    } catch (e) {
      debugPrint('Error loading dispute details: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _banUser(String userId, String banType,
      {DateTime? expiryDate}) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    await FirebaseFirestore.instance
        .collection(AppCollections.users)
        .doc(userId)
        .update({
      AppFields.userBannedStatus: banType,
      AppFields.userBannedReason:
          'Violated terms in delivery job dispute: ${widget.dispute.reason}',
      AppFields.userBannedUntil:
          expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
      'bannedAt': FieldValue.serverTimestamp(),
      'bannedBy': adminUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _handleAction(String action) async {
    setState(() => _isProcessing = true);
    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';

      if (action == 'resolve') {
        // Resolve dispute & restore job
        await DeliveryDisputeService().resolveDispute(
          disputeId: widget.dispute.id,
          jobId: widget.dispute.jobId,
          reviewerId: adminUid,
        );
      } else if (action == 'reject') {
        // Rejecting a dispute also resolves it and restores the job status
        await DeliveryDisputeService().resolveDispute(
          disputeId: widget.dispute.id,
          jobId: widget.dispute.jobId,
          reviewerId: adminUid,
        );
      } else if (action == 'ban_temp') {
        // Ban accused temporarily for 3 days, resolve dispute & restore job
        final expiry = DateTime.now().add(const Duration(days: 3));
        await _banUser(_accusedId, 'temporary', expiryDate: expiry);
        await DeliveryDisputeService().resolveDispute(
          disputeId: widget.dispute.id,
          jobId: widget.dispute.jobId,
          reviewerId: adminUid,
        );
      } else if (action == 'ban_payment') {
        // Ban accused until payment, resolve dispute & restore job
        await _banUser(_accusedId, 'until_payment');
        await DeliveryDisputeService().resolveDispute(
          disputeId: widget.dispute.id,
          jobId: widget.dispute.jobId,
          reviewerId: adminUid,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action applied successfully.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  String _getReasonLabel(String reason) {
    if (DeliveryDisputeSellerReasons.labels.containsKey(reason)) {
      return DeliveryDisputeSellerReasons.labels[reason]!;
    }
    if (DeliveryDisputeDriverReasons.labels.containsKey(reason)) {
      return DeliveryDisputeDriverReasons.labels[reason]!;
    }
    return reason;
  }

  @override
  Widget build(BuildContext context) {
    const Color red = Color(0xFFD32F2F);
    const Color bg = Color(0xFFF7F9FC);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Dispute Detail'),
        backgroundColor: red,
        foregroundColor: Colors.white,
      ),
      body: _isLoading || _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Dispute Context Card ──
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'OPEN DISPUTE',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              DateFormat('yyyy-MM-dd HH:mm')
                                  .format(widget.dispute.createdAt),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _getReasonLabel(widget.dispute.reason),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const Divider(height: 24),
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.dispute.description.isEmpty
                              ? 'No description provided.'
                              : widget.dispute.description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1E293B),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Involved Parties Card ──
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Involved Parties',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const Divider(height: 20),
                        _buildUserRow(
                          title: 'Reporter',
                          name: _reporterName,
                          email: _reporterEmail,
                          role: widget.dispute.filedBy == widget.dispute.sellerId
                              ? 'Seller'
                              : 'Driver',
                          icon: Icons.person,
                        ),
                        const SizedBox(height: 16),
                        _buildUserRow(
                          title: 'Accused',
                          name: _accusedName,
                          email: _accusedEmail,
                          role: widget.dispute.filedBy == widget.dispute.sellerId
                              ? 'Driver'
                              : 'Seller',
                          icon: Icons.person_outline,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Associated Job Card ──
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Associated Job',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const Divider(height: 20),
                        Text(
                          _jobTitle,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Status: $_jobStatus',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Action Buttons ──
                const Text(
                  'Actions',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _handleAction('reject'),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Reject & Dismiss Dispute'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _handleAction('resolve'),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Resolve (Restore Job Status)'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _handleAction('ban_temp'),
                  icon: const Icon(Icons.timer_off_outlined),
                  label: const Text('Accept & Ban Accused User (3 Days)'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _handleAction('ban_payment'),
                  icon: const Icon(Icons.money_off_rounded),
                  label: const Text('Accept & Ban Accused User (Until Paid)'),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildUserRow({
    required String title,
    required String name,
    required String email,
    required String role,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFFF1F5F9),
          child: Icon(icon, color: const Color(0xFF64748B)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                email,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  role,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
