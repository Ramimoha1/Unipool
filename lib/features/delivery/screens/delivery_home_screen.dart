// Delivery home — tab entry point that hosts driver and seller sub-views.
// Wraps both sub-screens inside a single Scaffold so they don't double-scaffold.
// Hallmark · pre-emit critique: P4 H4 E5 S4 R4 V4

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:unipool/core/constants.dart';
import 'package:unipool/core/widgets/app_bottom_nav.dart';
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

/// Entry point for the Delivery tab.
/// Provides a single Scaffold with a purple header and two tabs:
///   • Browse Jobs (driver browses open jobs)
///   • My Jobs     (seller manages posted jobs)
class DeliveryHomeScreen extends StatefulWidget {
  const DeliveryHomeScreen({super.key});

  @override
  State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}

class _DeliveryHomeScreenState extends State<DeliveryHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Start streaming open jobs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryProvider>().startOpenJobsStream();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        backgroundColor: _kPurple,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'Delivery',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Browse Jobs'),
            Tab(text: 'My Jobs'),
            Tab(text: 'Driver Jobs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _BrowseJobsBody(),
          _MyJobsBody(),
          _DriverJobsBody(),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Browse Jobs body (driver view)
// ─────────────────────────────────────────────────────────────────────────────

class _BrowseJobsBody extends StatefulWidget {
  const _BrowseJobsBody();

  @override
  State<_BrowseJobsBody> createState() => _BrowseJobsBodyState();
}

class _BrowseJobsBodyState extends State<_BrowseJobsBody>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<DeliveryProvider>();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final jobs = provider.openJobs;

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            if (provider.isLoading && jobs.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: _kPurple),
                ),
              )
            else if (jobs.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 56,
                          color: _kTextSecondary.withAlpha(100)),
                      const SizedBox(height: 12),
                      const Text(
                        'No delivery jobs yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _kTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Check back later or post your own job',
                        style:
                            TextStyle(fontSize: 13, color: _kTextSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList.separated(
                  itemCount: jobs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _JobCard(
                    job: jobs[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DeliveryJobDetailScreen(
                          job: jobs[i],
                          currentUid: currentUid,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),

        // ── FAB ──
        Positioned(
          right: 16,
          bottom: 24,
          child: FloatingActionButton(
            backgroundColor: _kPurple,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            heroTag: 'delivery_browse_fab',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PostJobScreen()),
            ),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// My Jobs body (seller view)
// ─────────────────────────────────────────────────────────────────────────────

class _MyJobsBody extends StatefulWidget {
  const _MyJobsBody();

  @override
  State<_MyJobsBody> createState() => _MyJobsBodyState();
}

class _MyJobsBodyState extends State<_MyJobsBody>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late final TabController _subTabController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(
      length: 2,
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryProvider>().loadMyJobs();
    });
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
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

    return Stack(
      children: [
        Column(
          children: [
            // Sub-tab bar
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _subTabController,
                labelColor: _kPurple,
                unselectedLabelColor: _kTextSecondary,
                indicatorColor: _kPurple,
                dividerColor: _kDivider,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(text: 'Active (${activeJobs.length})'),
                  Tab(text: 'Past (${pastJobs.length})'),
                ],
              ),
            ),
            Expanded(
              child: provider.isLoading && myJobs.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: _kPurple))
                  : TabBarView(
                      controller: _subTabController,
                      children: [
                        _JobListView(
                          jobs: activeJobs,
                          emptyMessage: 'No active jobs.',
                          currentUid: currentUid,
                        ),
                        _JobListView(
                          jobs: pastJobs,
                          emptyMessage: 'No past jobs yet.',
                          currentUid: currentUid,
                        ),
                      ],
                    ),
            ),
          ],
        ),

        // ── FAB ──
        Positioned(
          right: 16,
          bottom: 24,
          child: FloatingActionButton.extended(
            backgroundColor: _kPurple,
            foregroundColor: Colors.white,
            heroTag: 'delivery_myjobs_fab',
            icon: const Icon(Icons.add),
            label: const Text(
              'Post Job',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PostJobScreen()),
              ).then((_) {
                if (context.mounted) {
                  context.read<DeliveryProvider>().loadMyJobs();
                }
              });
            },
          ),
        ),
      ],
    );
  }
}

class _JobListView extends StatelessWidget {
  const _JobListView({
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
                size: 56, color: _kTextSecondary.withAlpha(100)),
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

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────


class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.onTap});

  final DeliveryJobModel job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stops = job.deliveryStops;
    final stopLabels = stops
        .map((s) => (s['label'] as String?) ?? '')
        .where((l) => l.isNotEmpty)
        .toList();
    final stopText = stopLabels.join(', ');
    final stopCount = stops.length;
    final timeText =
        '${DateFormat('h:mm a').format(job.timeWindowStart)} – '
        '${DateFormat('h:mm a').format(job.timeWindowEnd)}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 15, color: _kPurple),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pickup: ${job.pickupLabel}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _kTextPrimary,
                          ),
                        ),
                        if (stopText.isNotEmpty)
                          Text(
                            'Stops: $stopText',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _kTextSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.access_time_outlined,
                      size: 14, color: _kTextSecondary),
                  const SizedBox(width: 6),
                  Text(
                    timeText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _kTextSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(color: _kDivider, height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: _kPurpleLight,
                    child: Text(
                      job.sellerId.isNotEmpty
                          ? job.sellerId[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _kPurple,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      job.sellerId.length > 8
                          ? job.sellerId.substring(0, 8)
                          : job.sellerId,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _kTextSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '$stopCount ${stopCount == 1 ? 'stop' : 'stops'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: _kTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DeliveryJobDetailScreen(
              job: job,
              currentUid: currentUid,
            ),
          ),
        ).then((_) {
          if (context.mounted) {
            context.read<DeliveryProvider>().loadMyJobs();
          }
        });
      },
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
                  const SizedBox(height: 8),
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
                      border:
                          Border.all(color: statusColor.withAlpha(80)),
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
                  const Text(
                    'Manage →',
                    style: TextStyle(
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
        DeliveryJobStatuses.disputed => ('Disputed', Colors.orange),
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
        '\$${price.toStringAsFixed(0)}',
        style: const TextStyle(
          color: _kGreen,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Driver Jobs body (driver view)
// ─────────────────────────────────────────────────────────────────────────────

class _DriverJobsBody extends StatefulWidget {
  const _DriverJobsBody();

  @override
  State<_DriverJobsBody> createState() => _DriverJobsBodyState();
}

class _DriverJobsBodyState extends State<_DriverJobsBody>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late final TabController _subTabController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(
      length: 2,
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DeliveryProvider>();
      provider.startDriverJobsStream();
      provider.loadDriverJobs();
    });
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final provider = context.watch<DeliveryProvider>();
    final driverJobs = provider.driverJobs;

    final activeJobs = driverJobs.where((j) {
      return j.jobStatus != DeliveryJobStatuses.completed &&
          j.jobStatus != DeliveryJobStatuses.cancelled;
    }).toList();

    final pastJobs = driverJobs.where((j) {
      return j.jobStatus == DeliveryJobStatuses.completed ||
          j.jobStatus == DeliveryJobStatuses.cancelled;
    }).toList();

    return Column(
      children: [
        // Sub-tab bar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _subTabController,
            labelColor: _kPurple,
            unselectedLabelColor: _kTextSecondary,
            indicatorColor: _kPurple,
            dividerColor: _kDivider,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            tabs: [
              Tab(text: 'Active (${activeJobs.length})'),
              Tab(text: 'Past (${pastJobs.length})'),
            ],
          ),
        ),
        Expanded(
          child: provider.isLoading && driverJobs.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: _kPurple))
              : TabBarView(
                  controller: _subTabController,
                  children: [
                    _DriverJobListView(
                      jobs: activeJobs,
                      emptyMessage: 'No active driver jobs.',
                      currentUid: currentUid,
                    ),
                    _DriverJobListView(
                      jobs: pastJobs,
                      emptyMessage: 'No past driver jobs yet.',
                      currentUid: currentUid,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _DriverJobListView extends StatelessWidget {
  const _DriverJobListView({
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
                size: 56, color: _kTextSecondary.withAlpha(100)),
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
      onRefresh: () => context.read<DeliveryProvider>().loadDriverJobs(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: jobs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _DriverJobCard(
          job: jobs[i],
          currentUid: currentUid,
        ),
      ),
    );
  }
}

class _DriverJobCard extends StatelessWidget {
  const _DriverJobCard({required this.job, required this.currentUid});

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
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DeliveryJobDetailScreen(
              job: job,
              currentUid: currentUid,
            ),
          ),
        ).then((_) {
          if (context.mounted) {
            context.read<DeliveryProvider>().loadDriverJobs();
          }
        });
      },
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
                  const Text(
                    'Tap to manage →',
                    style: TextStyle(
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
          ('Assigned', const Color(0xFF0EA5E9)),
        DeliveryJobStatuses.inProgress =>
          ('In Progress', const Color(0xFF0EA5E9)),
        DeliveryJobStatuses.proofPending =>
          ('Proof Pending', const Color(0xFFF59E0B)),
        DeliveryJobStatuses.awaitingPayment =>
          ('Awaiting Payment', const Color(0xFFF59E0B)),
        DeliveryJobStatuses.completed => ('Completed', _kGreen),
        DeliveryJobStatuses.cancelled =>
          ('Cancelled', Colors.redAccent),
        DeliveryJobStatuses.disputed => ('Disputed', Colors.orange),
        _ => (status, _kTextSecondary),
      };
}

