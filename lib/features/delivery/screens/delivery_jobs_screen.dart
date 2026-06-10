// Hallmark · pre-emit critique: P4 H4 E5 S4 R4 V4
// Genre: playful/consumer · Theme: custom purple brand (matching app)
// Screen: Delivery Jobs List (Driver browse view)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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

class DeliveryJobsScreen extends StatefulWidget {
  const DeliveryJobsScreen({super.key});

  @override
  State<DeliveryJobsScreen> createState() => _DeliveryJobsScreenState();
}

class _DeliveryJobsScreenState extends State<DeliveryJobsScreen> {
  String _filter = 'all'; // 'all' | 'verified' | 'high_pay'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryProvider>().startOpenJobsStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryProvider>();
    final jobs = _applyFilter(provider.openJobs);
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: _kSurface,
      body: CustomScrollView(
        slivers: [
          // ── Header ──
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: _kPurple,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delivery Jobs',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Earn while you travel',
                    style: TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                  ),
                ),
              ),
            ),
          ),

          // ── Filter chips ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All Jobs',
                    selected: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Verified Only',
                    selected: _filter == 'verified',
                    onTap: () => setState(() => _filter = 'verified'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'High Pay',
                    selected: _filter == 'high_pay',
                    onTap: () => setState(() => _filter = 'high_pay'),
                  ),
                ],
              ),
            ),
          ),

          // ── Content ──
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
                        size: 56, color: _kTextSecondary.withAlpha(120)),
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
                      'Check back later or post your own',
                      style: TextStyle(fontSize: 13, color: _kTextSecondary),
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
                separatorBuilder: (_, __) => const SizedBox(height: 12),
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

      // ── FAB: seller posts a job ──
      floatingActionButton: FloatingActionButton(
        backgroundColor: _kPurple,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PostJobScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  List<DeliveryJobModel> _applyFilter(List<DeliveryJobModel> jobs) {
    return switch (_filter) {
      'verified' => jobs
          .where((j) => j.allowedDrivers == 'verified_only')
          .toList(),
      'high_pay' => [...jobs]..sort((a, b) => b.price.compareTo(a.price)),
      _ => jobs,
    };
  }
}

// ─── Job Card ─────────────────────────────────────────────────────────────────

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
    final initials = _initials(job.sellerId);

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
              // Title row
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
              const SizedBox(height: 12),

              // Pickup
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 16, color: _kPurple),
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

              // Time
              Row(
                children: [
                  const Icon(Icons.access_time_outlined,
                      size: 15, color: _kTextSecondary),
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
              const SizedBox(height: 12),
              const Divider(color: _kDivider, height: 1),
              const SizedBox(height: 10),

              // Seller row
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: _kPurpleLight,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 11,
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
                        fontSize: 13,
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

  String _initials(String uid) {
    if (uid.isEmpty) return '?';
    return uid.substring(0, 1).toUpperCase();
  }
}

// ─── Price Badge ──────────────────────────────────────────────────────────────

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

// ─── Filter Chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _kPurple : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _kPurple : _kDivider,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _kPurple.withAlpha(60),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : _kTextSecondary,
          ),
        ),
      ),
    );
  }
}
