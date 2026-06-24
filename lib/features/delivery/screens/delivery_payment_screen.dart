import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:unipool/features/carpool/widgets/payment_banner.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/delivery_payment_model.dart';
import '../providers/delivery_payment_provider.dart';

class DeliveryPaymentScreen extends StatefulWidget {
  const DeliveryPaymentScreen({super.key, required this.jobId});

  final String jobId;

  @override
  State<DeliveryPaymentScreen> createState() => _DeliveryPaymentScreenState();
}

class _DeliveryPaymentScreenState extends State<DeliveryPaymentScreen> {
  _SelectedProof? _selectedProof;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryPaymentProvider>().loadPayment(widget.jobId);
    });
  }

  bool _isSeller(DeliveryPaymentModel payment, String currentUid) {
    if (payment.sellerId.isNotEmpty) {
      return currentUid == payment.sellerId;
    }
    return currentUid != payment.bookedByUserId;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _selectedProof = _SelectedProof(
        bytes: bytes,
        fileName: picked.name.isNotEmpty ? picked.name : 'payment.jpg',
        mimeType: picked.mimeType ?? 'image/jpeg',
      );
    });
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() {
      _selectedProof = _SelectedProof(
        bytes: bytes,
        fileName: file.name,
        mimeType: 'application/pdf',
      );
    });
  }

  Future<void> _submitPayment(DeliveryPaymentModel payment) async {
    final sellerId = FirebaseAuth.instance.currentUser?.uid;
    if (sellerId == null) return;

    if (_selectedProof == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload a payment screenshot or PDF first.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await context.read<DeliveryPaymentProvider>().submitPaymentProof(
            paymentId: payment.id,
            jobId: widget.jobId,
            sellerId: sellerId,
            fileBytes: _selectedProof!.bytes,
            fileName: _selectedProof!.fileName,
            mimeType: _selectedProof!.mimeType,
          );
      if (!mounted) return;
      setState(() => _selectedProof = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment proof submitted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Consumer<DeliveryPaymentProvider>(
      builder: (context, paymentProvider, _) {
        final payment = paymentProvider.currentPayment;

        if (paymentProvider.isLoading && payment == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Payment')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (payment == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Payment')),
            body: const Center(child: Text('No payment record yet.')),
          );
        }

        final isSeller = _isSeller(payment, currentUid);

        return Scaffold(
          appBar: AppBar(
            title: Text(isSeller ? 'Pay Driver' : 'Payment Status'),
          ),
          body: isSeller
              ? _SellerPaymentView(
                  payment: payment,
                  selectedProof: _selectedProof,
                  submitting: _submitting || paymentProvider.isLoading,
                  onPickImage: _pickImage,
                  onPickPdf: _pickPdf,
                  onClearProof: () => setState(() => _selectedProof = null),
                  onSubmit: () => _submitPayment(payment),
                  onPayLater: payment.isSettled
                      ? null
                      : () => Navigator.pop(context),
                )
              : _DriverPaymentView(
                  jobId: widget.jobId,
                  payment: payment,
                ),
        );
      },
    );
  }
}

class _SelectedProof {
  const _SelectedProof({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;

  bool get isImage => mimeType.startsWith('image/');
}

class _SellerPaymentView extends StatelessWidget {
  const _SellerPaymentView({
    required this.payment,
    required this.selectedProof,
    required this.submitting,
    required this.onPickImage,
    required this.onPickPdf,
    required this.onClearProof,
    required this.onSubmit,
    required this.onPayLater,
  });

  final DeliveryPaymentModel payment;
  final _SelectedProof? selectedProof;
  final bool submitting;
  final VoidCallback onPickImage;
  final VoidCallback onPickPdf;
  final VoidCallback onClearProof;
  final VoidCallback onSubmit;
  final VoidCallback? onPayLater;

  @override
  Widget build(BuildContext context) {
    final hasBankDetails = payment.bankName.isNotEmpty ||
        payment.accountNumber.isNotEmpty ||
        payment.qrCodeUrl.isNotEmpty;

    if (payment.isSettled) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PaymentBanner(
            message: 'Payment submitted. The driver can view your proof.',
          ),
          const SizedBox(height: 16),
          _StatusCard(
            title: 'Payment Complete',
            subtitle: 'RM ${payment.totalAmount.toStringAsFixed(2)} paid',
            icon: Icons.check_circle,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          _PaymentProofViewer(payment: payment, label: 'Your uploaded proof'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PaymentBanner(
          message:
              'Transfer the amount to the driver, then upload proof of payment.',
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Amount Due: RM ${payment.totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        const SizedBox(height: 16),
        if (payment.bankName.isNotEmpty || payment.accountNumber.isNotEmpty)
          Card(
            color: const Color(0xFFF1F5F9),
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Driver Bank Details',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  if (payment.bankName.isNotEmpty)
                    Text('Bank: ${payment.bankName}'),
                  if (payment.accountNumber.isNotEmpty)
                    Text('Account: ${payment.accountNumber}'),
                  if (payment.accountHolderName.isNotEmpty)
                    Text('Name: ${payment.accountHolderName}'),
                ],
              ),
            ),
          ),
        if (payment.qrCodeUrl.isNotEmpty)
          Image.network(payment.qrCodeUrl, height: 220)
        else if (!hasBankDetails)
          const Text(
            'The driver has not set up payment details yet.',
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 24),
        const Text(
          'Upload Payment Proof',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        const Text(
          'Screenshot or PDF of your bank transfer receipt.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: submitting ? null : onPickImage,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Screenshot'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: submitting ? null : onPickPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF'),
              ),
            ),
          ],
        ),
        if (selectedProof != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (selectedProof!.isImage)
                    Image.memory(selectedProof!.bytes, height: 160)
                  else
                    ListTile(
                      leading:
                          const Icon(Icons.picture_as_pdf, color: Colors.red),
                      title: Text(
                        selectedProof!.fileName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: submitting ? null : onClearProof,
                      child: const Text('Remove'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: submitting || selectedProof == null ? null : onSubmit,
            child: submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Submit Payment'),
          ),
        ),
        if (onPayLater != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: submitting ? null : onPayLater,
              child: const Text('Pay Later'),
            ),
          ),
        ],
      ],
    );
  }
}

class _DriverPaymentView extends StatefulWidget {
  const _DriverPaymentView({
    required this.jobId,
    required this.payment,
  });

  final String jobId;
  final DeliveryPaymentModel payment;

  @override
  State<_DriverPaymentView> createState() => _DriverPaymentViewState();
}

class _DriverPaymentViewState extends State<_DriverPaymentView> {
  bool _confirming = false;

  Future<void> _confirmReceived() async {
    final driverId = FirebaseAuth.instance.currentUser?.uid;
    if (driverId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: const Text(
          'Have you received the payment in your account? '
          'Only confirm if the transfer matches the amount shown.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, I received it'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _confirming = true);
    try {
      await context.read<DeliveryPaymentProvider>().confirmPaymentReceived(
            paymentId: widget.payment.id,
            jobId: widget.jobId,
            driverId: driverId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment confirmed. You can now complete the job from the job page.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payment =
        context.watch<DeliveryPaymentProvider>().currentPayment ??
            widget.payment;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (payment.isSettled) ...[
          PaymentBanner(
            message: payment.driverConfirmedPayment
                ? 'Payment confirmed. Go back and tap Complete Job.'
                : 'The seller has paid you. Review the proof and confirm receipt.',
          ),
          const SizedBox(height: 16),
          _StatusCard(
            title: payment.driverConfirmedPayment
                ? 'Payment Confirmed'
                : 'Payment Submitted by Seller',
            subtitle:
                'RM ${payment.totalAmount.toStringAsFixed(2)} • ${_formatPaidAt(payment.paidAt)}',
            icon: payment.driverConfirmedPayment
                ? Icons.check_circle
                : Icons.payments_outlined,
            color: payment.driverConfirmedPayment ? Colors.green : Colors.teal,
          ),
          const SizedBox(height: 16),
          _PaymentProofViewer(
            payment: payment,
            label: 'Seller payment proof',
          ),
          if (!payment.driverConfirmedPayment) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _confirming ? null : _confirmReceived,
                child: _confirming
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Confirm Payment Received'),
              ),
            ),
          ],
        ] else ...[
          const PaymentBanner(
            message: 'Waiting for the seller to pay you.',
          ),
          const SizedBox(height: 16),
          _StatusCard(
            title: 'Payment Pending',
            subtitle:
                'You will receive RM ${payment.totalAmount.toStringAsFixed(2)} once the seller pays.',
            icon: Icons.schedule,
            color: Colors.orange,
          ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'The seller is transferring payment to your account. '
                'You will be able to view their transaction proof here once submitted.',
                style: TextStyle(color: Colors.grey, height: 1.4),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back'),
        ),
      ],
    );
  }

  String _formatPaidAt(DateTime? paidAt) {
    if (paidAt == null) return 'Just now';
    return '${paidAt.day}/${paidAt.month}/${paidAt.year}';
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class _PaymentProofViewer extends StatelessWidget {
  const _PaymentProofViewer({
    required this.payment,
    required this.label,
  });

  final DeliveryPaymentModel payment;
  final String label;

  Future<void> _openPdf(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open PDF.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (payment.paymentProofUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        if (payment.isImageProof)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              payment.paymentProofUrl,
              fit: BoxFit.contain,
            ),
          )
        else
          Card(
            child: ListTile(
              leading:
                  const Icon(Icons.picture_as_pdf, color: Colors.red, size: 36),
              title: const Text('Payment receipt (PDF)'),
              subtitle: const Text('Tap to open'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _openPdf(context, payment.paymentProofUrl),
            ),
          ),
      ],
    );
  }
}
