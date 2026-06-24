import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:unipool/core/constants.dart';
import 'package:unipool/features/carpool/models/ride_report_model.dart';
import 'package:unipool/features/delivery/models/delivery_dispute_model.dart';
import 'package:unipool/features/delivery/services/delivery_dispute_service.dart';
import 'admin_report_detail_screen.dart';
import 'admin_delivery_dispute_detail_screen.dart';

class AdminResolveDisputesScreen extends StatelessWidget {
  const AdminResolveDisputesScreen({super.key});

  static const Color _red = Color(0xFFD32F2F);
  static const Color _bg = Color(0xFFF7F9FC);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: const Text(
            'Resolve Disputes',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: _red,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(
                icon: Icon(Icons.directions_car_outlined),
                text: 'Transportation',
              ),
              Tab(
                icon: Icon(Icons.local_shipping_outlined),
                text: 'Delivery',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TransportationDisputesTab(),
            _DeliveryDisputesTab(),
          ],
        ),
      ),
    );
  }
}

// ─── Transportation Disputes Tab ───────────────────────────────────────────────

class _TransportationDisputesTab extends StatelessWidget {
  const _TransportationDisputesTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppCollections.rideReports)
          .where(AppFields.status, isEqualTo: CarpoolReportStatuses.open)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _EmptyStatePlaceholder(
            icon: Icons.check_circle_outline,
            message: 'No open transportation disputes.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final report = RideReportModel.fromMap(
              docs[index].data() as Map<String, dynamic>,
              docs[index].id,
            );

            return _DisputeCard(
              title: _getReasonLabel(report.reason),
              subtitle: 'Accused UID: ${report.targetUserId}',
              date: report.createdAt,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminReportDetailScreen(report: report),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _getReasonLabel(String reason) {
    switch (reason) {
      case CarpoolReportReasons.didNotPay:
        return 'Did not pay fare';
      case CarpoolReportReasons.unsafeDriver:
        return 'Unsafe driving';
      case CarpoolReportReasons.noShow:
        return 'No show / missed ride';
      case CarpoolReportReasons.other:
      default:
        return 'Other violation';
    }
  }
}

// ─── Delivery Disputes Tab ─────────────────────────────────────────────────────

class _DeliveryDisputesTab extends StatelessWidget {
  const _DeliveryDisputesTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DeliveryDisputeModel>>(
      stream: DeliveryDisputeService().getOpenDisputesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final disputes = snapshot.data ?? [];
        if (disputes.isEmpty) {
          return const _EmptyStatePlaceholder(
            icon: Icons.check_circle_outline,
            message: 'No open delivery disputes.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: disputes.length,
          itemBuilder: (context, index) {
            final dispute = disputes[index];

            return _DisputeCard(
              title: _getReasonLabel(dispute.reason),
              subtitle: 'Job ID: ${dispute.jobId}',
              date: dispute.createdAt,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminDeliveryDisputeDetailScreen(dispute: dispute),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _getReasonLabel(String reason) {
    if (DeliveryDisputeSellerReasons.labels.containsKey(reason)) {
      return DeliveryDisputeSellerReasons.labels[reason]!;
    }
    if (DeliveryDisputeDriverReasons.labels.containsKey(reason)) {
      return DeliveryDisputeDriverReasons.labels[reason]!;
    }
    return 'Other issue';
  }
}

// ─── Shared UI Components ──────────────────────────────────────────────────────

class _DisputeCard extends StatelessWidget {
  const _DisputeCard({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFF59E0B),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Filed: ${DateFormat('yyyy-MM-dd HH:mm').format(date)}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyStatePlaceholder extends StatelessWidget {
  const _EmptyStatePlaceholder({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
