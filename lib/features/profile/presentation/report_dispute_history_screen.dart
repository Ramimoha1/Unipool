import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:unipool/core/constants.dart';
import 'package:unipool/features/carpool/models/ride_report_model.dart';
import 'package:unipool/features/delivery/models/delivery_dispute_model.dart';
import 'package:unipool/features/delivery/services/delivery_dispute_service.dart';

class ReportDisputeHistoryScreen extends StatefulWidget {
  const ReportDisputeHistoryScreen({super.key});

  @override
  State<ReportDisputeHistoryScreen> createState() => _ReportDisputeHistoryScreenState();
}

class _ReportDisputeHistoryScreenState extends State<ReportDisputeHistoryScreen> {
  static const Color _teal = Color(0xFF1A9B8A);
  static const Color _purple = Color(0xFF7C3AED);
  static const Color _bgPage = Color(0xFFF7F9FC);
  
  final uid = FirebaseAuth.instance.currentUser?.uid;

  final Map<String, String> _nameCache = {};

  Future<String> _resolveName(String targetUid) async {
    if (_nameCache.containsKey(targetUid)) {
      return _nameCache[targetUid]!;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection(AppCollections.users)
          .doc(targetUid)
          .get();
      if (doc.exists) {
        final name = doc.data()?[AppFields.userFullName] as String?;
        if (name != null && name.isNotEmpty) {
          _nameCache[targetUid] = name;
          return name;
        }
      }
    } catch (_) {}
    _nameCache[targetUid] = targetUid;
    return targetUid;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // --- Carpool Helpers ---
  String _getCarpoolReasonLabel(String reason) {
    switch (reason) {
      case CarpoolReportReasons.didNotPay:
        return 'Did not pay';
      case CarpoolReportReasons.unsafeDriver:
        return 'Unsafe driver';
      case CarpoolReportReasons.noShow:
        return 'No show';
      case CarpoolReportReasons.other:
      default:
        return 'Other';
    }
  }

  Color _getCarpoolStatusColor(String status) {
    switch (status) {
      case CarpoolReportStatuses.resolved:
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case CarpoolReportStatuses.open:
      default:
        return Colors.orange;
    }
  }

  // --- Delivery Helpers ---
  String _getDeliveryReasonLabel(String reason) {
    if (DeliveryDisputeSellerReasons.labels.containsKey(reason)) {
      return DeliveryDisputeSellerReasons.labels[reason]!;
    }
    if (DeliveryDisputeDriverReasons.labels.containsKey(reason)) {
      return DeliveryDisputeDriverReasons.labels[reason]!;
    }
    return reason;
  }

  Color _getDeliveryStatusColor(String status) {
    switch (status) {
      case DeliveryDisputeStatuses.resolved:
        return Colors.green;
      case DeliveryDisputeStatuses.underReview:
        return Colors.blue;
      case DeliveryDisputeStatuses.open:
      default:
        return Colors.orange;
    }
  }

  Widget _buildBadge(String status, Color color) {
    String label = status.replaceAll('_', ' ').toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Reports & Disputes')),
        body: const Center(child: Text('Not logged in')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _bgPage,
        appBar: AppBar(
          title: const Text('My Reports & Disputes'),
          bottom: const TabBar(
            indicatorColor: _teal,
            labelColor: _teal,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Carpool'),
              Tab(text: 'Delivery'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildCarpoolTab(),
            _buildDeliveryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildCarpoolTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppCollections.rideReports)
          .where(AppFields.reportedBy, isEqualTo: uid)
          .orderBy(AppFields.createdAt, descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _teal));
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No reports filed yet.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final report = RideReportModel.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );

            final color = _getCarpoolStatusColor(report.status);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: _teal.withValues(alpha: 0.2),
                    child: const Icon(Icons.report_gmailerrorred, color: _teal),
                  ),
                  title: Text(
                    _getCarpoolReasonLabel(report.reason),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      FutureBuilder<String>(
                        future: _resolveName(report.targetUserId),
                        builder: (context, nameSnapshot) {
                          final nameStr = nameSnapshot.connectionState == ConnectionState.waiting
                              ? 'Loading...'
                              : (nameSnapshot.data ?? report.targetUserId);
                          return Text(
                            'Reported: $nameStr',
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                          );
                        },
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(report.createdAt),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      _buildBadge(report.status, color),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          report.description.isEmpty ? 'No description provided.' : report.description,
                          style: const TextStyle(color: Colors.black87, fontSize: 14),
                        ),
                      ),
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

  Widget _buildDeliveryTab() {
    return StreamBuilder<List<DeliveryDisputeModel>>(
      stream: DeliveryDisputeService().getDisputesFiledByMe(uid!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _purple));
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final disputes = snapshot.data ?? [];
        if (disputes.isEmpty) {
          return const Center(child: Text('No disputes filed yet.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: disputes.length,
          itemBuilder: (context, index) {
            final dispute = disputes[index];
            final color = _getDeliveryStatusColor(dispute.status);
            final targetUid = dispute.sellerId == uid ? dispute.driverId : dispute.sellerId;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: _purple.withValues(alpha: 0.2),
                    child: const Icon(Icons.gavel, color: _purple),
                  ),
                  title: Text(
                    _getDeliveryReasonLabel(dispute.reason),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      FutureBuilder<String>(
                        future: _resolveName(targetUid),
                        builder: (context, nameSnapshot) {
                          final nameStr = nameSnapshot.connectionState == ConnectionState.waiting
                              ? 'Loading...'
                              : (nameSnapshot.data ?? targetUid);
                          return Text(
                            'Reported: $nameStr',
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                          );
                        },
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(dispute.createdAt),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      _buildBadge(dispute.status, color),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          dispute.description.isEmpty ? 'No description provided.' : dispute.description,
                          style: const TextStyle(color: Colors.black87, fontSize: 14),
                        ),
                      ),
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
}
