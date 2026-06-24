import 'package:flutter/material.dart';
import 'package:unipool/features/profile/data/bank_details_repository.dart';
import 'package:unipool/features/profile/domain/bank_details_model.dart';

/// Bottom sheet shown when a driver applies to a delivery job.
/// They can enter payment details manually or load saved profile settings.
class DeliveryApplyPaymentSheet extends StatefulWidget {
  const DeliveryApplyPaymentSheet({
    super.key,
    required this.driverId,
    this.isReapply = false,
  });

  final String driverId;
  final bool isReapply;

  static Future<BankDetailsModel?> show(
    BuildContext context, {
    required String driverId,
    bool isReapply = false,
  }) {
    return showModalBottomSheet<BankDetailsModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DeliveryApplyPaymentSheet(
        driverId: driverId,
        isReapply: isReapply,
      ),
    );
  }

  @override
  State<DeliveryApplyPaymentSheet> createState() =>
      _DeliveryApplyPaymentSheetState();
}

class _DeliveryApplyPaymentSheetState extends State<DeliveryApplyPaymentSheet> {
  static const _teal = Color(0xFF1A9B8A);
  static const _textDark = Color(0xFF1A2332);
  static const _textMuted = Color(0xFF8A96A3);
  static const _border = Color(0xFFE5EAF0);

  final _repo = BankDetailsRepository();
  final _bankNameCtrl = TextEditingController();
  final _holderCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();

  String _qrCodeUrl = '';
  bool _loadingSaved = false;
  bool _usedSaved = false;

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _holderCtrl.dispose();
    _accountCtrl.dispose();
    super.dispose();
  }

  Future<void> _useSavedDetails() async {
    setState(() => _loadingSaved = true);
    try {
      final saved = await _repo.getBankDetails(widget.driverId);
      if (!mounted) return;
      if (saved.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No saved payment details found. Add them in Profile → Payment Settings first.',
            ),
          ),
        );
        return;
      }
      setState(() {
        _bankNameCtrl.text = saved.bankName;
        _holderCtrl.text = saved.accountHolderName;
        _accountCtrl.text = saved.accountNumber;
        _qrCodeUrl = saved.qrCodeUrl;
        _usedSaved = true;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load saved payment details.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingSaved = false);
    }
  }

  void _submit() {
    final details = BankDetailsModel(
      bankName: _bankNameCtrl.text.trim(),
      accountHolderName: _holderCtrl.text.trim(),
      accountNumber: _accountCtrl.text.trim(),
      qrCodeUrl: _qrCodeUrl,
    );

    if (details.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter bank details or tap "Use Saved Payment Settings".',
          ),
        ),
      );
      return;
    }

    final hasPartialBank = details.bankName.isNotEmpty ||
        details.accountHolderName.isNotEmpty ||
        details.accountNumber.isNotEmpty;
    if (hasPartialBank &&
        (details.bankName.isEmpty ||
            details.accountHolderName.isEmpty ||
            details.accountNumber.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all bank fields or use only a QR code.'),
        ),
      );
      return;
    }

    Navigator.pop(context, details);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset + 24),
      child: SingleChildScrollView(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.isReapply ? 'Re-apply with Payment Details' : 'Payment Details',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'The seller will use these details to pay you after delivery.',
                style: TextStyle(fontSize: 13, color: _textMuted, height: 1.4),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loadingSaved ? null : _useSavedDetails,
                icon: _loadingSaved
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Use Saved Payment Settings'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _teal,
                  side: const BorderSide(color: _teal),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              if (_usedSaved) ...[
                const SizedBox(height: 8),
                const Text(
                  'Loaded from your profile. You can still edit below.',
                  style: TextStyle(fontSize: 12, color: _teal),
                ),
              ],
              const SizedBox(height: 16),
              _field(
                controller: _bankNameCtrl,
                label: 'Bank Name',
                hint: 'e.g. Maybank',
              ),
              const SizedBox(height: 12),
              _field(
                controller: _holderCtrl,
                label: 'Account Holder Name',
                hint: 'Name on the account',
              ),
              const SizedBox(height: 12),
              _field(
                controller: _accountCtrl,
                label: 'Account Number',
                hint: 'Your bank account number',
                keyboardType: TextInputType.number,
              ),
              if (_qrCodeUrl.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'QR Code (from saved settings)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(_qrCodeUrl, height: 160, fit: BoxFit.contain),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.isReapply ? 'Submit Application' : 'Apply for Job',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
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
    );
  }
}
