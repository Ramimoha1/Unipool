// Hallmark · pre-emit critique: P4 H4 E5 S4 R4 V4
// Screen: My Delivery Jobs — Seller's posted jobs view

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:unipool/core/constants.dart';
import '../models/delivery_job_model.dart';
import '../providers/delivery_provider.dart';
import 'delivery_job_detail_screen.dart';
import 'post_job_screen.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kPurple = Color(0xFF7C3AED);
const _kPurpleLight = Color(0xFFF3EEFF);
const _kGreenBg = Color(0xFFECFBF3);
const _kGreen = Color(0xFF16A34A);
const _kSurface = Color(0xFFF8F8F8);
const _kCardBg = Colors.white;
const _kTextPrimary = Color(0xFF111827);
const _kTextSecondary = Color(0xFF6B7280);
const _kDivider = Color(0xFFE5E7EB);

class MyDeliveryJobsScreen extends StatefulWidget {
  const MyDeliveryJobsScreen({super.key});

  @override
  State<MyDeliveryJobsScreen> createState() => _MyDeliveryJobsScreenState();
}

class _MyDeliveryJobsScreenState extends State<MyDeliveryJobsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryProvider>().loadMyJobs();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid =
        FirebaseAuth.instance.currentUser?.uid ?? '';
    final provider = context.watch<DeliveryProvider>();
    final myJobs = provider.myJobs;

    final activeJobs = myJobs.where((j) {
      return j.jobStatus != DeliveryJobStatuses.completed &&
          j.jobStatus != DeliveryJobStatuses.cancelled;
    }).toList();

    final pastJobs = myJobs.where((j) {
      return j.jobStatus == DeliveryJobStatuses.completed ||
          j.jobStatus == DeliveryJobStatuses.cancelled;
    }).toList();

    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        backgroundColor: _kPurple,
        foregroundColor: Colors.white,
        title: const Text(
          'My Posted Jobs',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          tabs: [
            Tab(text: 'Active (${activeJobs.length})'),
            Tab(text: 'Past (${pastJobs.length})'),
          ],
        ),
      ),
      body: provider.isLoading && myJobs.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: _kPurple),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _JobList(
                  jobs: activeJobs,
                  emptyMessage: 'No active jobs. Post one!',
                  currentUid: currentUid,
                ),
                _JobList(
                  jobs: pastJobs,
                  emptyMessage: 'No past jobs yet.',
                  currentUid: currentUid,
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Post Job',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PostJobScreen()),
        ).then((_) => context.read<DeliveryProvider>().loadMyJobs()),
      ),
    );
  }
}

class _JobList extends StatelessWidget {
  const _JobList({
    required this.jobs,
    required this.emptyMessage,
    required this.currentUid,
  });

  final List<DeliveryJobModel> jobs;
  final String emptyMessage;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 56, color: _kTextSecondary.withAlpha(120)),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: const TextStyle(
                fontSize: 15,
                color: _kTextSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _kPurple,
      onRefresh: () => context.read<DeliveryProvider>().loadMyJobs(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: jobs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _MyJobCard(
          job: jobs[i],
          currentUid: currentUid,
        ),
      ),
    );
  }
}

class _MyJobCard extends StatelessWidget {
  const _MyJobCard({required this.job, required this.currentUid});

  final DeliveryJobModel job;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    final stops = job.deliveryStops;
    final stopCount = stops.length;
    final timeText =
        '${DateFormat('h:mm a').format(job.timeWindowStart)} – '
        '${DateFormat('h:mm a').format(job.timeWindowEnd)}';
    final (statusLabel, statusColor) = _statusInfo(job.jobStatus);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeliveryJobDetailScreen(
            job: job,
            currentUid: currentUid,
          ),
        ),
      ).then((_) => context.read<DeliveryProvider>().loadMyJobs()),
      child: Container(
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _kPurpleLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.inventory_2_outlined,
                            size: 18, color: _kPurple),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          job.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _kTextPrimary,
                          ),
                        ),
                      ),
                      _PriceBadge(price: job.price),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: _kTextSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${job.pickupLabel} → $stopCount ${stopCount == 1 ? 'stop' : 'stops'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _kTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time_outlined,
                          size: 14, color: _kTextSecondary),
                      const SizedBox(width: 4),
                      Text(
                        timeText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _kDivider)),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withAlpha(80)),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Tap to manage →',
                    style: const TextStyle(
                      fontSize: 12,
                      color: _kPurple,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, Color) _statusInfo(String status) => switch (status) {
        DeliveryJobStatuses.open => ('Open', _kPurple),
        DeliveryJobStatuses.driverAssigned =>
          ('Driver Assigned', const Color(0xFF0EA5E9)),
        DeliveryJobStatuses.inProgress =>
          ('In Progress', const Color(0xFF0EA5E9)),
        DeliveryJobStatuses.proofPending =>
          ('Proof Pending', const Color(0xFFF59E0B)),
        DeliveryJobStatuses.awaitingPayment =>
          ('Awaiting Payment', const Color(0xFFF59E0B)),
        DeliveryJobStatuses.completed => ('Completed', _kGreen),
        DeliveryJobStatuses.cancelled =>
          ('Cancelled', Colors.redAccent),
        DeliveryJobStatuses.disputed =>
          ('Disputed', Colors.orange),
        _ => (status, _kTextSecondary),
      };
}

class _PriceBadge extends StatelessWidget {
  const _PriceBadge({required this.price});
  final double price;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _kGreenBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'RM${price.toStringAsFixed(0)}',
        style: const TextStyle(
          color: _kGreen,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}
