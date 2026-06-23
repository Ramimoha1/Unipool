import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Admin screen to search all users and apply permanent or temporary bans.
///
/// Firestore fields written to `users/{uid}`:
///   isBanned        : bool
///   banType         : 'permanent' | 'temporary'
///   banReason       : String
///   bannedAt        : Timestamp
///   banExpiresAt    : Timestamp?   (null for permanent)
///   bannedBy        : String (admin uid)
///   isActive        : bool  (set false when banned)
class AdminBanUsersScreen extends StatefulWidget {
  const AdminBanUsersScreen({super.key});

  @override
  State<AdminBanUsersScreen> createState() => _AdminBanUsersScreenState();
}

class _AdminBanUsersScreenState extends State<AdminBanUsersScreen>
    with SingleTickerProviderStateMixin {
  static const Color _purple = Color(0xFF7C3AED);

  static const Color _bg = Color(0xFFF7F9FC);

  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(
        () => setState(() => _query = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Ban / Suspend Users',
            style: TextStyle(fontWeight: FontWeight.w600)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'All Users'),
            Tab(text: 'Banned'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Search bar ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by name or email…',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                prefixIcon: const Icon(Icons.search,
                    color: Color(0xFF9CA3AF), size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: Color(0xFF9CA3AF), size: 18),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5EAF0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5EAF0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _purple, width: 1.5),
                ),
              ),
            ),
          ),

          // ── Tab views ──────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _UserList(
                  query: _query,
                  showBannedOnly: false,
                ),
                _UserList(
                  query: _query,
                  showBannedOnly: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── User List ────────────────────────────────────────────────────────────────

class _UserList extends StatelessWidget {
  const _UserList({required this.query, required this.showBannedOnly});

  final String query;
  final bool showBannedOnly;

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> q =
        FirebaseFirestore.instance.collection('users');

    if (showBannedOnly) {
      q = q.where('isBanned', isEqualTo: true);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.orderBy('fullName').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF7C3AED)));
        }

        var docs = snapshot.data?.docs ?? [];

        // Client-side filter for search (Firestore doesn't support full-text)
        if (query.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data();
            final name =
                (data['fullName'] as String? ?? '').toLowerCase();
            final email =
                (data['email'] as String? ?? '').toLowerCase();
            return name.contains(query) || email.contains(query);
          }).toList();
        }

        // Exclude admins from the list
        docs = docs
            .where((d) {
              final roles = (d.data()['roles'] as List<dynamic>?)?.cast<String>() ?? [];
              return !roles.contains('admin');
            })
            .toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  showBannedOnly
                      ? Icons.check_circle_outline
                      : Icons.people_outline,
                  size: 56,
                  color: const Color(0xFFD1D5DB),
                ),
                const SizedBox(height: 12),
                Text(
                  showBannedOnly
                      ? 'No banned users'
                      : query.isNotEmpty
                          ? 'No users found'
                          : 'No users yet',
                  style: const TextStyle(
                      fontSize: 15, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          itemCount: docs.length,
          itemBuilder: (context, i) => _UserCard(doc: docs[i]),
        );
      },
    );
  }
}

// ─── User Card ────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  const _UserCard({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  static const Color _purple = Color(0xFF7C3AED);
  static const Color _red = Color(0xFFD32F2F);
  static const Color _green = Color(0xFF2E7D32);

  Map<String, dynamic> get data => doc.data();

  bool get isBanned => data['isBanned'] as bool? ?? false;
  String get banType => data['banType'] as String? ?? 'permanent';
  List<String> get roles =>
      (data['roles'] as List<dynamic>?)?.cast<String>() ?? ['student'];

  String _userTypeLabel() {
    if (roles.contains('verified_driver')) return 'Driver';
    if (roles.contains('driver_candidate')) return 'Driver';
    return 'Student';
  }

  Color _userTypeColor() {
    if (roles.contains('verified_driver') || roles.contains('driver_candidate')) {
      return const Color(0xFF1A9B8A);
    }
    return const Color(0xFF2563EB);
  }

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
    final name = data['fullName'] as String? ?? 'Unknown';
    final email = data['email'] as String? ?? '';
    final university = data['university'] as String? ?? '';

    // Ban expiry (for temporary bans)
    final expiresAt =
        (data['banExpiresAt'] as Timestamp?)?.toDate();
    final isExpired =
        expiresAt != null && expiresAt.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isBanned && !isExpired
            ? Border.all(color: _red.withValues(alpha: 0.3), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── User info row ──────────────────────────────────────────
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _userTypeColor().withValues(alpha: 0.12),
                  child: Text(
                    _initials(name),
                    style: TextStyle(
                      color: _userTypeColor(),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A2332))),
                      Text(email,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF6B7280))),
                      if (university.isNotEmpty)
                        Text(university,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
                // User type badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _userTypeColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _userTypeLabel(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _userTypeColor()),
                  ),
                ),
              ],
            ),

            // ── Active ban info ────────────────────────────────────────
            if (isBanned && !isExpired) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F5),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.block,
                            size: 14, color: Color(0xFFD32F2F)),
                        const SizedBox(width: 6),
                        Text(
                          banType == 'permanent'
                              ? 'Permanently Banned'
                              : 'Temporarily Suspended',
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD32F2F)),
                        ),
                      ],
                    ),
                    if (data['banReason'] != null &&
                        (data['banReason'] as String).isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Reason: ${data['banReason']}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ],
                    if (expiresAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Expires: ${_formatDate(expiresAt)}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // ── Action buttons ─────────────────────────────────────────
            Row(
              children: [
                if (!isBanned || isExpired) ...[
                  Expanded(
                    child: _ActionBtn(
                      label: 'Temp Suspend',
                      icon: Icons.access_time_outlined,
                      color: const Color(0xFFF59E0B),
                      onTap: () => _showBanDialog(
                          context, doc.id, name, isTemporary: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionBtn(
                      label: 'Perm Ban',
                      icon: Icons.block_outlined,
                      color: _red,
                      onTap: () => _showBanDialog(
                          context, doc.id, name, isTemporary: false),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: _ActionBtn(
                      label: 'Lift Ban',
                      icon: Icons.lock_open_outlined,
                      color: _green,
                      onTap: () => _liftBan(context, doc.id, name),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionBtn(
                      label: 'Change Ban',
                      icon: Icons.edit_outlined,
                      color: _purple,
                      onTap: () => _showBanDialog(
                          context, doc.id, name,
                          isTemporary: banType == 'temporary'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  // ─── Ban Dialog ─────────────────────────────────────────────────────────

  void _showBanDialog(
    BuildContext context,
    String userId,
    String userName, {
    required bool isTemporary,
  }) {
    final reasonCtrl = TextEditingController();
    DateTime? expiryDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isTemporary
                    ? Icons.access_time_outlined
                    : Icons.block_outlined,
                color: isTemporary
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFD32F2F),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isTemporary
                      ? 'Temporarily Suspend'
                      : 'Permanently Ban',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User: $userName',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 16),

                // Reason field
                const Text('Reason *',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText:
                        'Describe the violation…',
                    hintStyle: const TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 13),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),

                // Expiry date picker (temporary only)
                if (isTemporary) ...[
                  const SizedBox(height: 16),
                  const Text('Suspension ends on *',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now()
                            .add(const Duration(days: 7)),
                        firstDate: DateTime.now()
                            .add(const Duration(days: 1)),
                        lastDate: DateTime.now()
                            .add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDlgState(() => expiryDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: const Color(0xFFD1D5DB)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 16, color: Color(0xFF6B7280)),
                          const SizedBox(width: 10),
                          Text(
                            expiryDate != null
                                ? '${expiryDate!.year}-${expiryDate!.month.toString().padLeft(2, '0')}-${expiryDate!.day.toString().padLeft(2, '0')}'
                                : 'Pick a date',
                            style: TextStyle(
                              fontSize: 13,
                              color: expiryDate != null
                                  ? const Color(0xFF1A2332)
                                  : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Warning box
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isTemporary
                        ? const Color(0xFFFFFBEB)
                        : const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isTemporary
                          ? const Color(0xFFFDE68A)
                          : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Text(
                    isTemporary
                        ? 'The user will be unable to log in until the suspension period ends.'
                        : 'This action is permanent. The user will be banned indefinitely and cannot log in.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isTemporary
                          ? const Color(0xFF92400E)
                          : const Color(0xFF991B1B),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF6B7280))),
            ),
            ElevatedButton(
              onPressed: () async {
                final reason = reasonCtrl.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please provide a reason.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (isTemporary && expiryDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please pick an expiry date.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);
                await _applyBan(
                  context: context,
                  userId: userId,
                  userName: userName,
                  reason: reason,
                  isTemporary: isTemporary,
                  expiryDate: expiryDate,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isTemporary
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(isTemporary ? 'Suspend' : 'Ban User'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Apply Ban ───────────────────────────────────────────────────────────

  Future<void> _applyBan({
    required BuildContext context,
    required String userId,
    required String userName,
    required String reason,
    required bool isTemporary,
    DateTime? expiryDate,
  }) async {
    final adminUid =
        FirebaseAuth.instance.currentUser?.uid ?? 'admin';

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'isBanned': true,
        'isActive': false,
        'banType': isTemporary ? 'temporary' : 'permanent',
        'banReason': reason,
        'bannedAt': FieldValue.serverTimestamp(),
        'banExpiresAt': expiryDate != null
            ? Timestamp.fromDate(expiryDate)
            : null,
        'bannedBy': adminUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isTemporary
                  ? '$userName has been suspended.'
                  : '$userName has been permanently banned.',
            ),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // ─── Lift Ban ────────────────────────────────────────────────────────────

  Future<void> _liftBan(
      BuildContext context, String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Lift Ban'),
        content: Text(
            'Are you sure you want to restore access for $userName?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF6B7280)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('Lift Ban'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'isBanned': false,
        'isActive': true,
        'banType': FieldValue.delete(),
        'banReason': FieldValue.delete(),
        'bannedAt': FieldValue.delete(),
        'banExpiresAt': FieldValue.delete(),
        'bannedBy': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$userName\'s ban has been lifted.'),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ─── Action Button ────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label,
          style: const TextStyle(fontSize: 12.5)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}