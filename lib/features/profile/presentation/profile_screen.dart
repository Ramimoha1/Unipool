import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:unipool/core/widgets/app_bottom_nav.dart';
import '../data/driver_verification_repository.dart';
import 'apply_driver_screen.dart';
import 'package:unipool/features/profile/presentation/account_settings_screen.dart';
import 'package:unipool/features/profile/presentation/payment_settings_screen.dart';
import 'package:unipool/features/profile/presentation/payment_history_screen.dart';
import 'package:unipool/features/profile/presentation/report_dispute_history_screen.dart';
import 'package:unipool/features/auth/presentation/auth_gate.dart';
import 'package:unipool/features/carpool/services/carpool_service.dart';
import 'package:unipool/features/carpool/screens/request_detail_screen.dart';
import 'package:unipool/features/delivery/screens/my_delivery_jobs_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _teal = Color(0xFF1A9B8A);
  static const Color _bgPage = Color(0xFFF7F9FC);

  final _repo = DriverVerificationRepository(
    firestore: FirebaseFirestore.instance,
  );

  Future<void> _goToApply() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ApplyDriverScreen()),
    );
    if (result == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in.')));
    }

    return Scaffold(
      backgroundColor: _bgPage,
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _repo.userStream(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _teal));
          }

          final userData = snapshot.data ?? {};
          final verificationStatus =
              userData['verificationStatus'] as String? ?? 'unverified';
          final roles = (userData['roles'] as List<dynamic>?)?.cast<String>() ?? ['student'];
          final fullName =
              userData['fullName'] as String? ?? user.displayName ?? 'User';
          final university = userData['university'] as String? ?? '';
          final photoUrl = userData['profilePhotoUrl'] as String?;
          final rides = userData['totalRides'] as int? ?? 0;
          final deliveries = userData['totalDeliveries'] as int? ?? 0;
          final rating = (userData['rating'] as num?)?.toDouble() ?? 0.0;
          // Admin rejection note (written by admin when rejecting driver app)
          final rejectionNote = userData['rejectionNote'] as String?;
          
          final bannedStatus = userData['bannedStatus'] as String? ?? 'none';
          final bannedReason = userData['bannedReason'] as String? ?? 'No reason provided';

          return CustomScrollView(
            slivers: [
              _buildAppBar(fullName, university, verificationStatus, photoUrl),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (bannedStatus != 'none')
                        _BannedBanner(
                          bannedStatus: bannedStatus,
                          bannedReason: bannedReason,
                        ),
                      _StatsRow(
                          rides: rides,
                          deliveries: deliveries,
                          rating: rating),
                      const SizedBox(height: 24),
                      _DriverStatusCard(
                        verificationStatus: verificationStatus,
                        roles: roles,
                        rejectionNote: rejectionNote,
                        onApply: _goToApply,
                      ),
                      const SizedBox(height: 24),
                      _QuickActionsCard(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }

  SliverAppBar _buildAppBar(
    String fullName,
    String university,
    String verificationStatus,
    String? photoUrl,
  ) {
    // expandedHeight needs enough room: status bar + app bar + profile content
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: _teal,
      elevation: 0,
      // When collapsed, show title
      title: const Text(
        'Profile',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthGate()),
              (route) => false,
            );
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        // Disable the built-in title so our custom content doesn't clash
        title: null,
        collapseMode: CollapseMode.pin,
        background: SafeArea(
          child: Padding(
            // top: leave room for the appbar row (~56px) + a little breathing
            padding: const EdgeInsets.fromLTRB(20, 64, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Avatar ──────────────────────────────────────────────
                _ProfileAvatar(photoUrl: photoUrl, fullName: fullName),
                const SizedBox(width: 16),
                // ── Name / university / badge ────────────────────────────
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (university.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Student • $university',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      _StatusBadge(verificationStatus),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Banned Banner ────────────────────────────────────────────────────────────

class _BannedBanner extends StatelessWidget {
  const _BannedBanner({required this.bannedStatus, required this.bannedReason});
  final String bannedStatus;
  final String bannedReason;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.block, color: Color(0xFFDC2626)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Account Suspended', style: TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Status: $bannedStatus', style: const TextStyle(color: Color(0xFF991B1B), fontSize: 14)),
                Text('Reason: $bannedReason', style: const TextStyle(color: Color(0xFF991B1B), fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Profile Avatar ───────────────────────────────────────────────────────────

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.photoUrl, required this.fullName});

  final String? photoUrl;
  final String fullName;

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 36,
      backgroundColor: Colors.white.withValues(alpha: 0.25),
      backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
      child: photoUrl == null
          ? Text(
              _initials(fullName),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg, icon) = switch (status) {
      'approved' || 'verified_driver' => (
          'Verified Driver',
          Colors.white,
          const Color(0xFF1A9B8A),
          Icons.verified_outlined
        ),
      'pending' => (
          'Pending Verification',
          Colors.white,
          const Color(0xFFF59E0B),
          Icons.hourglass_empty_outlined
        ),
      'rejected' => (
          'Verification Rejected',
          Colors.white,
          const Color(0xFFE53935),
          Icons.cancel_outlined
        ),
      _ => (
          'Not Verified',
          Colors.white.withValues(alpha: 0.2),
          Colors.white,
          Icons.info_outline
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                color: fg, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─── Stats Row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow(
      {required this.rides,
      required this.deliveries,
      required this.rating});

  final int rides;
  final int deliveries;
  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatCell(
              value: '$rides',
              label: 'Rides',
              color: const Color(0xFF1A9B8A)),
          _Divider(),
          _StatCell(
              value: '$deliveries',
              label: 'Deliveries',
              color: const Color(0xFF7C3AED)),
          _Divider(),
          _StatCell(
            value: rating > 0 ? rating.toStringAsFixed(1) : '—',
            label: 'Rating',
            color: const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell(
      {required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF8A96A3))),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: const Color(0xFFE5EAF0));
}

// ─── Driver Status Card ───────────────────────────────────────────────────────

class _DriverStatusCard extends StatelessWidget {
  const _DriverStatusCard({
    required this.verificationStatus,
    required this.roles,
    required this.onApply,
    this.rejectionNote,
  });

  final String verificationStatus;
  final List<String> roles;
  final VoidCallback onApply;
  final String? rejectionNote;

  static const Color _teal = Color(0xFF1A9B8A);
  static const Color _red = Color(0xFFE53935);

  @override
  Widget build(BuildContext context) {
    final isRejected = verificationStatus == 'rejected';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Driver Status',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A2332)),
          ),
          const SizedBox(height: 14),
          _StatusDetail(verificationStatus: verificationStatus),

          // ── Rejection note button ────────────────────────────────────
          if (isRejected) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showRejectionNote(context),
              icon: const Icon(Icons.info_outline, size: 16),
              label: const Text('View reason from admin'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _red,
                side: const BorderSide(color: Color(0xFFE53935)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],

          // ── Apply / re-apply link ────────────────────────────────────
          if (verificationStatus != 'approved' &&
              verificationStatus != 'verified_driver') ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: verificationStatus == 'pending' ? null : onApply,
              child: Text(
                verificationStatus == 'pending'
                    ? 'Application under review…'
                    : verificationStatus == 'rejected'
                        ? 'Re-apply to be a Verified Driver →'
                        : 'Apply to be a Verified Driver →',
                style: TextStyle(
                  fontSize: 13.5,
                  color: verificationStatus == 'pending'
                      ? const Color(0xFF8A96A3)
                      : _teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showRejectionNote(BuildContext context) {
    final note = (rejectionNote != null && rejectionNote!.trim().isNotEmpty)
        ? rejectionNote!.trim()
        : 'No specific reason was provided by the admin.';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.cancel_outlined, color: Color(0xFFE53935), size: 20),
            SizedBox(width: 8),
            Text(
              'Rejection Reason',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A2332)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(
                note,
                style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF374151),
                    height: 1.5),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'You may re-apply after addressing the issue above.',
              style:
                  TextStyle(fontSize: 12.5, color: Color(0xFF8A96A3)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close',
                style: TextStyle(color: Color(0xFF1A9B8A))),
          ),
        ],
      ),
    );
  }
}

class _StatusDetail extends StatelessWidget {
  const _StatusDetail({required this.verificationStatus});
  final String verificationStatus;

  @override
  Widget build(BuildContext context) {
    final (icon, iconColor, bgColor, title, subtitle) =
        switch (verificationStatus) {
      'approved' || 'verified_driver' => (
          Icons.verified_outlined,
          const Color(0xFF2E7D32),
          const Color(0xFFE8F5E9),
          'Verified Driver',
          'You are approved to drive.'
        ),
      'pending' => (
          Icons.hourglass_top_outlined,
          const Color(0xFFF59E0B),
          const Color(0xFFFFF8E1),
          'Verification Pending',
          'Application under review'
        ),
      'rejected' => (
          Icons.cancel_outlined,
          const Color(0xFFE53935),
          const Color(0xFFFFEBEE),
          'Verification Rejected',
          'Your documents were not accepted'
        ),
      _ => (
          Icons.shield_outlined,
          const Color(0xFF8A96A3),
          const Color(0xFFF0F4F8),
          'Not Verified',
          'Submit documents to become a driver'
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: iconColor)),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF6B7280))),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Quick Actions Card ───────────────────────────────────────────────────────

class _QuickActionsCard extends StatelessWidget {
  static const Color _teal = Color(0xFF1A9B8A);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Actions',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A2332))),
          const SizedBox(height: 8),
          _ActionRow(
              icon: Icons.location_on_outlined,
              iconColor: _teal,
              label: 'My Carpool Requests',
              onTap: () async {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid == null) return;
                
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator(color: _teal)),
                );
                
                try {
                  final carpools = await CarpoolService().getActiveCarpoolsForUser(uid);
                  if (!context.mounted) return;
                  Navigator.pop(context); // close dialog
                  
                  if (carpools.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RequestDetailScreen(requestId: carpools.first.id),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('You currently have no active carpool session.')),
                    );
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  Navigator.pop(context); // close dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }),
          _ActionRow(
              icon: Icons.inventory_2_outlined,
              iconColor: const Color(0xFF7C3AED),
              label: 'My Delivery Jobs',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MyDeliveryJobsScreen()),
              )),
          _ActionRow(
              icon: Icons.history,
              iconColor: Colors.orange,
              label: 'Payment History',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PaymentHistoryScreen()),
              )),
          _ActionRow(
              icon: Icons.credit_card_outlined,
              iconColor: const Color(0xFF2563EB),
              label: 'Payment Settings',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PaymentSettingsScreen()),
              )),
          _ActionRow(
              icon: Icons.report_gmailerrorred_outlined,
              iconColor: const Color(0xFFE53935),
              label: 'My Reports & Disputes',
              isLast: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ReportDisputeHistoryScreen()),
              )),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.isLast = false,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap ?? () {},
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A2332))),
                ),
                const Icon(Icons.chevron_right,
                    color: Color(0xFFB0BAC8), size: 20),
              ],
            ),
          ),
        ),
        if (!isLast) const Divider(height: 1, color: Color(0xFFEEF2F7)),
      ],
    );
  }
}
