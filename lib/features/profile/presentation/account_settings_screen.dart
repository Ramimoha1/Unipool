import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Account settings screen. Accessible from the settings icon on ProfileScreen.
///
/// Sections:
///   1. Profile Photo — upload / change avatar
///   2. Personal Info — edit display name, phone number, university, matric number
///   3. Security — change password, re-authentication guard
///   4. Notifications — toggle preferences (stored in Firestore)
///   5. Account — sign out, delete account (destructive, confirm dialog)
class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  // ─── Constants ───────────────────────────────────────────────────────────
  static const Color _teal = Color(0xFF1A9B8A);
  static const Color _tealLight = Color(0xFFE8F7F5);
  static const Color _red = Color(0xFFE53935);
  static const Color _redLight = Color(0xFFFFEBEE);
  static const Color _textDark = Color(0xFF1A2332);
  static const Color _textMuted = Color(0xFF8A96A3);
  static const Color _border = Color(0xFFE5EAF0);
  static const Color _bgPage = Color(0xFFF7F9FC);

  // ─── State ───────────────────────────────────────────────────────────────
  Map<String, dynamic> _userData = {};
  bool _loadingData = true;

  // Notification toggles (mirrored from Firestore)
  bool _notifRideUpdates = true;
  bool _notifDeliveryUpdates = true;
  bool _notifPromotions = false;
  bool _notifAppUpdates = true;

  final _user = FirebaseAuth.instance.currentUser!;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final doc = await _firestore.collection('users').doc(_user.uid).get();
    if (!mounted) return;
    final data = doc.data() ?? {};
    final notif = data['notificationPreferences'] as Map<String, dynamic>? ?? {};
    setState(() {
      _userData = data;
      _notifRideUpdates = notif['rideUpdates'] as bool? ?? true;
      _notifDeliveryUpdates = notif['deliveryUpdates'] as bool? ?? true;
      _notifPromotions = notif['promotions'] as bool? ?? false;
      _notifAppUpdates = notif['appUpdates'] as bool? ?? true;
      _loadingData = false;
    });
  }

  // ─── Photo ────────────────────────────────────────────────────────────────

  Future<void> _changePhoto() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (picked == null) return;

    _showLoadingSnack('Uploading photo…');

    try {
      // readAsBytes works on web AND mobile — no dart:io File needed
      final bytes = await picked.readAsBytes();
      final mimeType = picked.mimeType ?? 'image/jpeg';
      final ext = picked.name.split('.').last.toLowerCase();

      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos/${_user.uid}/avatar.$ext');

      await ref.putData(bytes, SettableMetadata(contentType: mimeType));
      final url = await ref.getDownloadURL();

      await Future.wait([
        _firestore.collection('users').doc(_user.uid).update({
          'profilePhotoUrl': url,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
        _user.updatePhotoURL(url),
      ]);

      setState(() => _userData['profilePhotoUrl'] = url);
      _showSuccess('Profile photo updated!');
    } catch (e, stack) {
      debugPrint('=== PHOTO UPLOAD ERROR ===');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error: $e');
      debugPrint('Stack: $stack');
      debugPrint('==========================');
      _showError('Failed: ${e.toString()}');
    }
  }

  // ─── Edit Name ────────────────────────────────────────────────────────────

  Future<void> _editField({
    required String title,
    required String firestoreKey,
    required String currentValue,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.words,
    String? Function(String?)? validator,
  }) async {
    final ctrl = TextEditingController(text: currentValue);
    final formKey = GlobalKey<FormState>();

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5EAF0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: ctrl,
                autofocus: true,
                keyboardType: keyboardType,
                textCapitalization: capitalization,
                validator: validator ??
                    (v) => (v == null || v.trim().isEmpty)
                        ? 'This field cannot be empty'
                        : null,
                style: const TextStyle(fontSize: 15, color: _textDark),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: _textMuted),
                  filled: true,
                  fillColor: const Color(0xFFF7F9FC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _teal, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(ctx, ctrl.text.trim());
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null || result == currentValue) return;

    try {
      await _firestore.collection('users').doc(_user.uid).update({
        firestoreKey: result,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Keep Firebase Auth display name in sync
      if (firestoreKey == 'fullName') await _user.updateDisplayName(result);

      setState(() => _userData[firestoreKey] = result);
      _showSuccess('$title updated!');
    } catch (e) {
      _showError('Failed to update. Please try again.');
    }
  }

  // ─── Change Password ──────────────────────────────────────────────────────

  Future<void> _changePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5EAF0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Change Password',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 16),
                _PasswordField(
                  controller: currentCtrl,
                  hint: 'Current password',
                  obscure: obscureCurrent,
                  onToggle: () =>
                      setModalState(() => obscureCurrent = !obscureCurrent),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter current password' : null,
                ),
                const SizedBox(height: 12),
                _PasswordField(
                  controller: newCtrl,
                  hint: 'New password',
                  obscure: obscureNew,
                  onToggle: () =>
                      setModalState(() => obscureNew = !obscureNew),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter new password';
                    if (v.length < 8) return 'At least 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _PasswordField(
                  controller: confirmCtrl,
                  hint: 'Confirm new password',
                  obscure: obscureConfirm,
                  onToggle: () =>
                      setModalState(() => obscureConfirm = !obscureConfirm),
                  validator: (v) =>
                      v != newCtrl.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(ctx);
                      await _doChangePassword(
                          currentCtrl.text, newCtrl.text);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Update Password',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _doChangePassword(String current, String newPass) async {
    _showLoadingSnack('Updating password…');
    try {
      // Re-authenticate before sensitive operation
      final cred = EmailAuthProvider.credential(
        email: _user.email!,
        password: current,
      );
      await _user.reauthenticateWithCredential(cred);
      await _user.updatePassword(newPass);
      _showSuccess('Password updated successfully!');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _showError('Current password is incorrect.');
      } else {
        _showError('Failed to update password. Please try again.');
      }
    }
  }

  // ─── Notifications ────────────────────────────────────────────────────────

  Future<void> _updateNotifPref(String key, bool value) async {
    try {
      await _firestore.collection('users').doc(_user.uid).update({
        'notificationPreferences.$key': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Revert on failure — the calling setState already set optimistically
      _showError('Failed to update notification preference.');
    }
  }

  // ─── Sign Out ─────────────────────────────────────────────────────────────

  Future<void> _signOut() async {
    final confirmed = await _showConfirmDialog(
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Sign Out',
      isDestructive: false,
    );
    if (!confirmed) return;
    await FirebaseAuth.instance.signOut();
    // AuthGate will handle routing back to login
  }

  // ─── Delete Account ───────────────────────────────────────────────────────

  Future<void> _deleteAccount() async {
    final confirmed = await _showConfirmDialog(
      title: 'Delete Account',
      message:
          'This will permanently delete your account and all your data. This action cannot be undone.',
      confirmLabel: 'Delete Account',
      isDestructive: true,
    );
    if (!confirmed) return;

    // Require re-auth for account deletion
    final passwordCtrl = TextEditingController();
    final reauthed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Identity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your password to confirm deletion.'),
            const SizedBox(height: 12),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm',
                style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );

    if (reauthed != true) return;

    _showLoadingSnack('Deleting account…');

    try {
      final cred = EmailAuthProvider.credential(
        email: _user.email!,
        password: passwordCtrl.text,
      );
      await _user.reauthenticateWithCredential(cred);

      // Delete Firestore document first, then Auth account
      await _firestore.collection('users').doc(_user.uid).delete();
      await _user.delete();
      // AuthGate routes back to login automatically
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _showError('Incorrect password. Account not deleted.');
      } else {
        _showError('Failed to delete account. Please try again.');
      }
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _showLoadingSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(msg),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _teal,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _red,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required bool isDestructive,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: _textDark)),
            content: Text(message,
                style: const TextStyle(color: _textMuted, fontSize: 14)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel',
                    style: TextStyle(color: _textMuted)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  confirmLabel,
                  style: TextStyle(
                    color: isDestructive ? _red : _teal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      appBar: AppBar(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Account Settings',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
      ),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                // ── 1. Profile Photo ─────────────────────────────────────
                _ProfilePhotoSection(
                  photoUrl: _userData['profilePhotoUrl'] as String?,
                  initials: _initials(
                      _userData['fullName'] as String? ?? _user.email ?? '?'),
                  onTap: _changePhoto,
                ),

                const SizedBox(height: 20),

                // ── 2. Personal Info ──────────────────────────────────────
                _SectionCard(
                  title: 'Personal Information',
                  children: [
                    _SettingsTile(
                      icon: Icons.person_outline,
                      iconColor: _teal,
                      label: 'Full Name',
                      value: _userData['fullName'] as String? ?? '—',
                      onTap: () => _editField(
                        title: 'Full Name',
                        firestoreKey: 'fullName',
                        currentValue:
                            _userData['fullName'] as String? ?? '',
                        hint: 'e.g. Ahmad bin Ali',
                        capitalization: TextCapitalization.words,
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.phone_outlined,
                      iconColor: const Color(0xFF2563EB),
                      label: 'Phone Number',
                      value: (_userData['phoneNumber'] as String?)
                                  ?.isNotEmpty ==
                              true
                          ? _userData['phoneNumber'] as String
                          : 'Not set',
                      onTap: () => _editField(
                        title: 'Phone Number',
                        firestoreKey: 'phoneNumber',
                        currentValue:
                            _userData['phoneNumber'] as String? ?? '',
                        hint: 'e.g. +601X-XXXXXXX',
                        keyboardType: TextInputType.phone,
                        capitalization: TextCapitalization.none,
                        validator: (v) => null, // optional field
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.school_outlined,
                      iconColor: const Color(0xFF7C3AED),
                      label: 'University',
                      value: (_userData['university'] as String?)
                                  ?.isNotEmpty ==
                              true
                          ? _userData['university'] as String
                          : '—',
                      onTap: () => _editField(
                        title: 'University',
                        firestoreKey: 'university',
                        currentValue:
                            _userData['university'] as String? ?? '',
                        hint: 'e.g. Universiti Putra Malaysia',
                        capitalization: TextCapitalization.words,
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.badge_outlined,
                      iconColor: const Color(0xFFF59E0B),
                      label: 'Matric Number',
                      value: (_userData['matricNumber'] as String?)
                                  ?.isNotEmpty ==
                              true
                          ? _userData['matricNumber'] as String
                          : '—',
                      isLast: true,
                      onTap: () => _editField(
                        title: 'Matric Number',
                        firestoreKey: 'matricNumber',
                        currentValue:
                            _userData['matricNumber'] as String? ?? '',
                        hint: 'e.g. A0123456X',
                        capitalization: TextCapitalization.characters,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── 3. Security ───────────────────────────────────────────
                _SectionCard(
                  title: 'Security',
                  children: [
                    _SettingsTile(
                      icon: Icons.mail_outline,
                      iconColor: _teal,
                      label: 'Email Address',
                      value: _user.email ?? '—',
                      onTap: null, // email change requires verification flow
                      trailing: const _LockedBadge(),
                    ),
                    _SettingsTile(
                      icon: Icons.lock_outline,
                      iconColor: const Color(0xFF2563EB),
                      label: 'Change Password',
                      value: '••••••••',
                      isLast: true,
                      onTap: _changePassword,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── 4. Notifications ──────────────────────────────────────
                _SectionCard(
                  title: 'Notifications',
                  children: [
                    _ToggleTile(
                      icon: Icons.directions_car_outlined,
                      iconColor: _teal,
                      label: 'Ride Updates',
                      subtitle: 'Status changes for your carpool requests',
                      value: _notifRideUpdates,
                      onChanged: (v) {
                        setState(() => _notifRideUpdates = v);
                        _updateNotifPref('rideUpdates', v);
                      },
                    ),
                    _ToggleTile(
                      icon: Icons.inventory_2_outlined,
                      iconColor: const Color(0xFF7C3AED),
                      label: 'Delivery Updates',
                      subtitle: 'Progress on your delivery jobs',
                      value: _notifDeliveryUpdates,
                      onChanged: (v) {
                        setState(() => _notifDeliveryUpdates = v);
                        _updateNotifPref('deliveryUpdates', v);
                      },
                    ),
                    _ToggleTile(
                      icon: Icons.campaign_outlined,
                      iconColor: const Color(0xFFF59E0B),
                      label: 'Promotions',
                      subtitle: 'Deals, discounts and special offers',
                      value: _notifPromotions,
                      onChanged: (v) {
                        setState(() => _notifPromotions = v);
                        _updateNotifPref('promotions', v);
                      },
                    ),
                    _ToggleTile(
                      icon: Icons.system_update_outlined,
                      iconColor: const Color(0xFF2563EB),
                      label: 'App Updates',
                      subtitle: 'New features and announcements',
                      value: _notifAppUpdates,
                      isLast: true,
                      onChanged: (v) {
                        setState(() => _notifAppUpdates = v);
                        _updateNotifPref('appUpdates', v);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── 5. Account ────────────────────────────────────────────
                _SectionCard(
                  title: 'Account',
                  children: [
                    _SettingsTile(
                      icon: Icons.logout,
                      iconColor: _textMuted,
                      label: 'Sign Out',
                      value: '',
                      showChevron: false,
                      onTap: _signOut,
                    ),
                    _SettingsTile(
                      icon: Icons.delete_outline,
                      iconColor: _red,
                      label: 'Delete Account',
                      value: '',
                      labelColor: _red,
                      showChevron: false,
                      isLast: true,
                      onTap: _deleteAccount,
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // App version
                Center(
                  child: Text(
                    'UniPool v0.1.0',
                    style: TextStyle(
                      color: _textMuted.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}

// ─── Profile Photo Section ────────────────────────────────────────────────────

class _ProfilePhotoSection extends StatelessWidget {
  const _ProfilePhotoSection({
    required this.photoUrl,
    required this.initials,
    required this.onTap,
  });

  final String? photoUrl;
  final String initials;
  final VoidCallback onTap;

  static const Color _teal = Color(0xFF1A9B8A);
  static const Color _tealLight = Color(0xFFE8F7F5);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 46,
                  backgroundColor: _tealLight,
                  backgroundImage:
                      photoUrl != null ? NetworkImage(photoUrl!) : null,
                  child: photoUrl == null
                      ? Text(
                          initials,
                          style: const TextStyle(
                            color: _teal,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: _teal,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onTap,
            child: const Text(
              'Change Photo',
              style: TextStyle(
                color: _teal,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8A96A3),
                letterSpacing: 0.8,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

// ─── Settings Tile ────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onTap,
    this.trailing,
    this.labelColor,
    this.showChevron = true,
    this.isLast = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? labelColor;
  final bool showChevron;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(14),
            bottom: isLast ? const Radius.circular(14) : Radius.zero,
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: iconColor, size: 17),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: labelColor ?? const Color(0xFF1A2332),
                        ),
                      ),
                      if (value.isNotEmpty)
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF8A96A3),
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (showChevron && onTap != null)
                  const Icon(Icons.chevron_right,
                      color: Color(0xFFB0BAC8), size: 20),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 64, color: Color(0xFFEEF2F7)),
      ],
    );
  }
}

// ─── Toggle Tile ──────────────────────────────────────────────────────────────

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isLast = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLast;

  static const Color _teal = Color(0xFF1A9B8A);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconColor, size: 17),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A2332),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A96A3),
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeColor: _teal,
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 64, color: Color(0xFFEEF2F7)),
      ],
    );
  }
}

// ─── Locked Badge ─────────────────────────────────────────────────────────────

class _LockedBadge extends StatelessWidget {
  const _LockedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Fixed',
        style: TextStyle(
          fontSize: 11,
          color: Color(0xFF8A96A3),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─── Password Field (used inside Change Password bottom sheet) ─────────────────

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.hint,
    required this.obscure,
    required this.onToggle,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: Color(0xFF1A2332)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: const Color(0xFF9CA3AF),
            size: 20,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: const Color(0xFFF7F9FC),
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
          borderSide:
              const BorderSide(color: Color(0xFF1A9B8A), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935)),
        ),
      ),
    );
  }
}