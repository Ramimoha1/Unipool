import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'admin_driver_applications_screen.dart';
import 'admin_ban_users_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  static const Color _red = Color(0xFFD32F2F);
  static const Color _bg = Color(0xFFF7F9FC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _AdminHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatsSection(),
                  const SizedBox(height: 28),
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A2332),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _QuickAction(
                    icon: Icons.person_search_outlined,
                    iconColor: _red,
                    label: 'Review Driver Applications',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AdminDriverApplicationsScreen()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _QuickAction(
                    icon: Icons.block_outlined,
                    iconColor: const Color(0xFF7C3AED),
                    label: 'Ban / Suspend Users',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminBanUsersScreen()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _QuickAction(
                    icon: Icons.warning_amber_outlined,
                    iconColor: const Color(0xFFF59E0B),
                    label: 'Resolve Disputes',
                    onTap: () {},
                  ),
                  const SizedBox(height: 10),
                  _QuickAction(
                    icon: Icons.flag_outlined,
                    iconColor: const Color(0xFF2563EB),
                    label: 'Review Reports',
                    onTap: () {},
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _AdminHeader extends StatelessWidget {
  static const Color _red = Color(0xFFD32F2F);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _red,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Admin Dashboard',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                Text('Platform Moderator',
                    style:
                        TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
    );
  }
}

// ─── Stats Section ────────────────────────────────────────────────────────────

class _StatsSection extends StatelessWidget {
  static const Color _red = Color(0xFFD32F2F);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StatCard(
          icon: Icons.person_outline,
          iconColor: _red,
          label: 'Pending Applications',
          collection: 'driverApplications',
          filterField: 'status',
          filterValue: 'pending',
        ),
        const SizedBox(height: 12),
        _StatCard(
          icon: Icons.block_outlined,
          iconColor: const Color(0xFF7C3AED),
          label: 'Banned Users',
          collection: 'users',
          filterField: 'isBanned',
          filterValue: true,
        ),
        const SizedBox(height: 12),
        _StatCard(
          icon: Icons.warning_amber_outlined,
          iconColor: const Color(0xFFF59E0B),
          label: 'Open Disputes',
          collection: 'disputes',
          filterField: 'status',
          filterValue: 'open',
        ),
        const SizedBox(height: 12),
        _StatCard(
          icon: Icons.flag_outlined,
          iconColor: const Color(0xFF2563EB),
          label: 'Recent Reports',
          collection: 'reports',
          filterField: 'reviewed',
          filterValue: false,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.collection,
    required this.filterField,
    required this.filterValue,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String collection;
  final String filterField;
  final Object filterValue;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where(filterField, isEqualTo: filterValue)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border(left: BorderSide(color: iconColor, width: 4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF6B7280))),
                    Text('$count',
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A2332))),
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

// ─── Quick Action Row ─────────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.isLast = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A2332))),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFB0BAC8)),
          ],
        ),
      ),
    );
  }
}