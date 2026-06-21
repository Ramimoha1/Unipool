import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/bank_details_repository.dart';
import '../domain/bank_details_model.dart';

/// Screen for managing bank / payment details (QR code + bank info).
///
/// Accessible from the "Payment Settings" quick-action on the profile page.
/// Visual style matches [AccountSettingsScreen].
class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  // ─── Constants ──────────────────────────────────────────────────────────
  static const Color _teal = Color(0xFF1A9B8A);
  static const Color _tealLight = Color(0xFFE8F7F5);
  static const Color _red = Color(0xFFE53935);
  static const Color _textDark = Color(0xFF1A2332);
  static const Color _textMuted = Color(0xFF8A96A3);
  static const Color _border = Color(0xFFE5EAF0);
  static const Color _bgPage = Color(0xFFF7F9FC);

  // ─── State ──────────────────────────────────────────────────────────────
  final _repo = BankDetailsRepository();
  final _user = FirebaseAuth.instance.currentUser!;

  BankDetailsModel _details = const BankDetailsModel();
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final details = await _repo.getBankDetails(_user.uid);
      if (!mounted) return;
      setState(() {
        _details = details;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading bank details: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      _showError('Failed to load payment settings. Please check your connection or firestore rules.');
    }
  }

  // ─── QR Upload ──────────────────────────────────────────────────────────

  Future<void> _uploadQr() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    _showLoadingSnack('Uploading QR code…');

    try {
      final url = await _repo.uploadQrImage(_user.uid, picked);
      final updated = _details.copyWith(qrCodeUrl: url);
      await _repo.saveBankDetails(_user.uid, updated);
      setState(() {
        _details = updated;
        _uploading = false;
      });
      _showSuccess('QR code uploaded!');
    } catch (e) {
      setState(() => _uploading = false);
      _showError('Failed to upload QR code.');
    }
  }

  // ─── Edit Field ─────────────────────────────────────────────────────────

  Future<void> _editField({
    required String title,
    required String currentValue,
    required BankDetailsModel Function(String newValue) updater,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.words,
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
                validator: (v) => (v == null || v.trim().isEmpty)
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
                      fontWeight: FontWeight.w600,
                    ),
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
      final updated = updater(result);
      await _repo.saveBankDetails(_user.uid, updated);
      setState(() => _details = updated);
      _showSuccess('$title updated!');
    } catch (e) {
      _showError('Failed to update. Please try again.');
    }
  }

  // ─── Delete ─────────────────────────────────────────────────────────────

  Future<void> _deleteBankDetails() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove Payment Details',
          style: TextStyle(fontWeight: FontWeight.bold, color: _textDark),
        ),
        content: const Text(
          'This will remove your bank details and QR code. Payers will not see your payment info until you add it again.',
          style: TextStyle(color: _textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: _red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _repo.deleteBankDetails(_user.uid);
      setState(() => _details = const BankDetailsModel());
      _showSuccess('Payment details removed.');
    } catch (e) {
      _showError('Failed to remove. Please try again.');
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  void _showLoadingSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 12),
            Text(msg),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      appBar: AppBar(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Payment Settings',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                // ── 1. QR Code Section ─────────────────────────────────
                _QrCodeSection(
                  qrCodeUrl: _details.qrCodeUrl,
                  uploading: _uploading,
                  onUpload: _uploadQr,
                ),

                const SizedBox(height: 20),

                // ── 2. Bank Details Section ─────────────────────────────
                _SectionCard(
                  title: 'Bank Details',
                  children: [
                    _SettingsTile(
                      icon: Icons.account_balance_outlined,
                      iconColor: _teal,
                      label: 'Bank Name',
                      value: _details.bankName.isNotEmpty
                          ? _details.bankName
                          : 'Not set',
                      onTap: () => _editField(
                        title: 'Bank Name',
                        currentValue: _details.bankName,
                        hint: 'e.g. Maybank, CIMB, Bank Islam',
                        updater: (v) => _details.copyWith(bankName: v),
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.person_outline,
                      iconColor: const Color(0xFF2563EB),
                      label: 'Account Holder Name',
                      value: _details.accountHolderName.isNotEmpty
                          ? _details.accountHolderName
                          : 'Not set',
                      onTap: () => _editField(
                        title: 'Account Holder Name',
                        currentValue: _details.accountHolderName,
                        hint: 'e.g. Ahmad bin Ali',
                        updater: (v) =>
                            _details.copyWith(accountHolderName: v),
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.numbers_outlined,
                      iconColor: const Color(0xFF7C3AED),
                      label: 'Account Number',
                      value: _details.accountNumber.isNotEmpty
                          ? _details.accountNumber
                          : 'Not set',
                      isLast: true,
                      onTap: () => _editField(
                        title: 'Account Number',
                        currentValue: _details.accountNumber,
                        hint: 'e.g. 1234567890',
                        keyboardType: TextInputType.number,
                        capitalization: TextCapitalization.none,
                        updater: (v) => _details.copyWith(accountNumber: v),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── 3. Info Note ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _tealLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline,
                            color: _teal, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your QR code and bank details will be shown to payers once a ride or delivery is completed.',
                            style: TextStyle(
                              fontSize: 13,
                              color: _teal.withValues(alpha: 0.85),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── 4. Remove Section ──────────────────────────────────
                if (_details.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionCard(
                    title: 'Danger Zone',
                    children: [
                      _SettingsTile(
                        icon: Icons.delete_outline,
                        iconColor: _red,
                        label: 'Remove Payment Details',
                        value: '',
                        labelColor: _red,
                        showChevron: false,
                        isLast: true,
                        onTap: _deleteBankDetails,
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// ─── QR Code Section ────────────────────────────────────────────────────────────

class _QrCodeSection extends StatelessWidget {
  const _QrCodeSection({
    required this.qrCodeUrl,
    required this.uploading,
    required this.onUpload,
  });

  final String qrCodeUrl;
  final bool uploading;
  final VoidCallback onUpload;

  static const Color _teal = Color(0xFF1A9B8A);
  static const Color _tealLight = Color(0xFFE8F7F5);
  static const Color _textMuted = Color(0xFF8A96A3);

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
              'PAYMENT QR CODE',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF8A96A3),
                letterSpacing: 0.8,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // QR image or placeholder
                if (qrCodeUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      qrCodeUrl,
                      height: 200,
                      width: 200,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          height: 200,
                          width: 200,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: _teal,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 200,
                        width: 200,
                        decoration: BoxDecoration(
                          color: _tealLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image_outlined,
                                color: _teal, size: 40),
                            SizedBox(height: 8),
                            Text(
                              'Failed to load image',
                              style:
                                  TextStyle(color: _textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: uploading ? null : onUpload,
                    child: Container(
                      height: 180,
                      width: 180,
                      decoration: BoxDecoration(
                        color: _tealLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _teal.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_2_outlined,
                            color: _teal.withValues(alpha: 0.6),
                            size: 48,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Tap to upload QR code',
                            style: TextStyle(
                              color: _teal.withValues(alpha: 0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                // Change / Upload button
                GestureDetector(
                  onTap: uploading ? null : onUpload,
                  child: Text(
                    uploading
                        ? 'Uploading…'
                        : qrCodeUrl.isNotEmpty
                            ? 'Change QR Code'
                            : 'Upload QR Code',
                    style: TextStyle(
                      color: uploading ? _textMuted : _teal,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
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
                  color: Colors.black.withValues(alpha: 0.04),
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
    this.labelColor,
    this.showChevron = true,
    this.isLast = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback? onTap;
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
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
                if (showChevron && onTap != null)
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
