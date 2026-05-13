import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/driver_verification_repository.dart';
import 'apply_driver_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ─── Constants ───────────────────────────────────────────────────────────
  static const Color _teal = Color(0xFF1A9B8A);
  static const Color _bgPage = Color(0xFFF7F9FC);

  final _repo = DriverVerificationRepository(
    firestore: FirebaseFirestore.instance,
  );

  // ─── Navigation to Apply screen ──────────────────────────────────────────
  Future<void> _goToApply() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ApplyDriverScreen()),
    );
    // `result == true` means the user just submitted — the stream will refresh
    // automatically, but setState forces a rebuild just in case.
    if (result == true && mounted) setState(() {});
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in.')),
      );
    }

    return Scaffold(
      backgroundColor: _bgPage,
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _repo.userStream(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _teal),
            );
          }

          final userData = snapshot.data ?? {};
          final verificationStatus =
              userData['verificationStatus'] as String? ?? 'unverified';
          final userType = userData['userType'] as String? ?? 'student';
          final fullName = userData['fullName'] as String? ?? user.displayName ?? 'User';
          final university = userData['university'] as String? ?? '';
          final rides = userData['totalRides'] as int? ?? 0;
          final deliveries = userData['totalDeliveries'] as int? ?? 0;
          final rating = (userData['rating'] as num?)?.toDouble() ?? 0.0;

          return CustomScrollView(
            slivers: [
              _buildAppBar(fullName, university, verificationStatus),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatsRow(
                        rides: rides,
                        deliveries: deliveries,
                        rating: rating,
                      ),
                      const SizedBox(height: 24),
                      _DriverStatusCard(
                        verificationStatus: verificationStatus,
                        userType: userType,
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
      bottomNavigationBar: _BottomNav(currentIndex: 2),
    );
  }

  SliverAppBar _buildAppBar(
      String fullName, String university, String verificationStatus) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: _teal,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
          onPressed: () {},
        ),
        IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: _teal,
          padding: const EdgeInsets.fromLTRB(20, 70, 20, 20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                child: Text(
                  _initials(fullName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (university.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Student • $university',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
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
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
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
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats Row ───────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.rides,
    required this.deliveries,
    required this.rating,
  });

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
          _StatCell(value: '$rides', label: 'Rides', color: const Color(0xFF1A9B8A)),
          _Divider(),
          _StatCell(value: '$deliveries', label: 'Deliveries', color: const Color(0xFF7C3AED)),
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
  const _StatCell({required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF8A96A3)),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: const Color(0xFFE5EAF0));
  }
}

// ─── Driver Status Card ───────────────────────────────────────────────────────

class _DriverStatusCard extends StatelessWidget {
  const _DriverStatusCard({
    required this.verificationStatus,
    required this.userType,
    required this.onApply,
  });

  final String verificationStatus;
  final String userType;
  final VoidCallback onApply;

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
          const Text(
            'Driver Status',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A2332),
            ),
          ),
          const SizedBox(height: 14),
          _StatusDetail(verificationStatus: verificationStatus),
          if (verificationStatus != 'approved' &&
              verificationStatus != 'verified_driver') ...[
            const SizedBox(height: 14),
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
                  decoration: verificationStatus != 'pending'
                      ? TextDecoration.none
                      : null,
                ),
              ),
            ),
          ],
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
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  color: iconColor,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
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
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A2332),
            ),
          ),
          const SizedBox(height: 8),
          _ActionRow(
            icon: Icons.location_on_outlined,
            iconColor: _teal,
            label: 'My Carpool Requests',
          ),
          _ActionRow(
            icon: Icons.inventory_2_outlined,
            iconColor: const Color(0xFF7C3AED),
            label: 'My Delivery Jobs',
          ),
          _ActionRow(
            icon: Icons.credit_card_outlined,
            iconColor: const Color(0xFF2563EB),
            label: 'Payment Settings',
            isLast: true,
          ),
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
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () {},
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
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A2332),
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFFB0BAC8), size: 20),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Divider(height: 1, color: Color(0xFFEEF2F7)),
      ],
    );
  }
}
// ─── Bottom Navigation ────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex});
  final int currentIndex;

  static const Color _teal = Color(0xFF1A9B8A);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: _teal,
      unselectedItemColor: const Color(0xFF8A96A3),
      selectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5),
      unselectedLabelStyle: const TextStyle(fontSize: 11.5),
      backgroundColor: Colors.white,
      elevation: 8,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.directions_car_outlined),
          activeIcon: Icon(Icons.directions_car),
          label: 'Carpool',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2_outlined),
          activeIcon: Icon(Icons.inventory_2),
          label: 'Delivery',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
      onTap: (_) {},
    );
  }
}

