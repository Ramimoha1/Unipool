import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminDriverApplicationsScreen extends StatelessWidget {
  const AdminDriverApplicationsScreen({super.key});

  static const Color _red = Color(0xFFD32F2F);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: _red,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Driver Applications',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('driverApplications')
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _red));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 56, color: Color(0xFF1A9B8A)),
                  SizedBox(height: 12),
                  Text(
                    'No pending applications',
                    style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              _PendingBanner(count: docs.length),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, i) =>
                      _ApplicationCard(doc: docs[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Banner ───────────────────────────────────────────────────────────────────

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$count pending application${count == 1 ? '' : 's'}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFF59E0B),
              ),
            ),
            const TextSpan(
              text: ' waiting for review.',
              style: TextStyle(color: Color(0xFF92400E)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Application Card ─────────────────────────────────────────────────────────

class _ApplicationCard extends StatefulWidget {
  const _ApplicationCard({required this.doc});
  final QueryDocumentSnapshot doc;

  @override
  State<_ApplicationCard> createState() => _ApplicationCardState();
}

class _ApplicationCardState extends State<_ApplicationCard> {
  final _noteController = TextEditingController();
  bool _isProcessing = false;

  Map<String, dynamic> get _data => widget.doc.data() as Map<String, dynamic>;

  Future<void> _decide(String decision) async {
    setState(() => _isProcessing = true);
    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    final userId = _data['userId'] as String;

    try {
      final batch = FirebaseFirestore.instance.batch();

      // Update the application
      batch.update(
        FirebaseFirestore.instance
            .collection('driverApplications')
            .doc(widget.doc.id),
        {
          'status': decision,
          'reviewedBy': adminUid,
          'reviewedAt': FieldValue.serverTimestamp(),
          'notes': _noteController.text.trim(),
        },
      );

      // Update the user document
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(userId),
        {
          'verificationStatus': decision,
          'userType': decision == 'approved' ? 'verified_driver' : 'student',
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Application ${decision == 'approved' ? 'approved ✓' : 'rejected'}'),
            backgroundColor: decision == 'approved'
                ? const Color(0xFF2E7D32)
                : const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = (_data['createdAt'] as Timestamp?)?.toDate();
    final dateStr = createdAt != null
        ? '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}'
        : '—';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(_data['userId'] as String)
          .get(),
      builder: (context, userSnap) {
        final userData =
            userSnap.data?.data() as Map<String, dynamic>? ?? {};
        final name = userData['fullName'] as String? ?? 'Unknown';
        final university = userData['university'] as String? ?? '';
        final matric = userData['matricNumber'] as String? ?? '—';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A2332),
                            ),
                          ),
                          if (university.isNotEmpty)
                            Text(university,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF6B7280))),
                          Text(
                            'Matric: $matric',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF6B7280)),
                          ),
                          Text(
                            'Submitted: $dateStr',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Pending',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFEEF2F7)),
              // ── Documents ──
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_data['studentCardUrl'] != null)
                      _DocRow(
                        icon: Icons.badge_outlined,
                        label: 'Matric Card',
                        url: _data['studentCardUrl'] as String,
                      ),
                    if (_data['driverLicenseUrl'] != null)
                      _DocRow(
                        icon: Icons.credit_card_outlined,
                        label: "Driver's License",
                        url: _data['driverLicenseUrl'] as String,
                      ),
                  ],
                ),
              ),
              // ── Note field ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    hintText: 'Add optional note (reason for rejection…)',
                    hintStyle: const TextStyle(
                        fontSize: 12.5, color: Color(0xFFB0BAC8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE5EAF0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE5EAF0)),
                    ),
                  ),
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              // ── Action buttons ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            _isProcessing ? null : () => _decide('approved'),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            _isProcessing ? null : () => _decide('rejected'),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Reject'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD32F2F),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Document Row ─────────────────────────────────────────────────────────────

class _DocRow extends StatelessWidget {
  const _DocRow({required this.icon, required this.label, required this.url});
  final IconData icon;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5EAF0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6B7280)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF1A2332)),
            ),
          ),
          GestureDetector(
            onTap: () => _previewImage(context, url),
            child: const Icon(Icons.visibility_outlined,
                size: 18, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  void _previewImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(label),
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              elevation: 0,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            Image.network(
              url,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
              errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(40),
                child: Text('Failed to load image'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
