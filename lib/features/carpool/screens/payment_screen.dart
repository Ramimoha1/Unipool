import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unipool/core/constants.dart';
import '../providers/payment_provider.dart';
import '../services/carpool_service.dart';
import '../widgets/payment_banner.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _carpoolService = CarpoolService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaymentProvider>().loadPayment(widget.requestId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: Consumer<PaymentProvider>(
        builder: (context, paymentProvider, _) {
          final payment = paymentProvider.currentPayment;
          if (paymentProvider.isLoading && payment == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (payment == null) {
            return const Center(child: Text('No payment record yet.'));
          }

          return FutureBuilder(
            future: _carpoolService.getGroupByRequestId(widget.requestId),
            builder: (context, groupSnapshot) {
              final members = groupSnapshot.data?.memberIds ?? const [];
              final isPayee = currentUid == payment.bookedByUserId;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (payment.bankName.isNotEmpty || payment.accountNumber.isNotEmpty)
                    Card(
                      color: const Color(0xFFF1F5F9),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Bank Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            if (payment.bankName.isNotEmpty) Text('Bank: ${payment.bankName}'),
                            if (payment.accountNumber.isNotEmpty) Text('Account: ${payment.accountNumber}'),
                            if (payment.accountHolderName.isNotEmpty) Text('Name: ${payment.accountHolderName}'),
                          ],
                        ),
                      ),
                    ),
                  if (payment.qrCodeUrl.isNotEmpty)
                    Image.network(payment.qrCodeUrl, height: 220)
                  else if (payment.bankName.isEmpty && payment.accountNumber.isEmpty)
                    const Center(child: Text('Payment details not available yet.')),
                  const SizedBox(height: 16),
                  if (!isPayee)
                    Center(child: Text('Amount Due: RM ${payment.splitAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                  const SizedBox(height: 24),
                  const PaymentBanner(message: 'Confirm payment once you have paid.'),
                  const SizedBox(height: 16),
                  ...members.where((memberId) {
                    if (isPayee) {
                      return memberId != currentUid;
                    } else {
                      return memberId == currentUid;
                    }
                  }).map((memberId) {
                    final confirmed = payment.confirmedBy.contains(memberId);
                    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      future: FirebaseFirestore.instance.collection(AppCollections.users).doc(memberId).get(),
                      builder: (context, userSnapshot) {
                        final userData = userSnapshot.data?.data() ?? const <String, dynamic>{};
                        final displayName = (userData[AppFields.userFullName] as String?)?.trim();
                        final verificationStatus = (userData[AppFields.userVerificationStatus] as String?) ?? 'unverified';
                        final name = displayName != null && displayName.isNotEmpty ? displayName : memberId;

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: Icon(confirmed ? Icons.check_circle : Icons.schedule, color: confirmed ? Colors.green : Colors.grey),
                            title: Text(name),
                            subtitle: Text('Due: RM ${payment.splitAmount.toStringAsFixed(2)} • ${confirmed ? 'Paid' : 'Pending'} • ${_verificationLabel(verificationStatus)}'),
                          ),
                        );
                      },
                    );
                  }),
                  if (!isPayee && !payment.confirmedBy.contains(currentUid))
                    FilledButton(
                      onPressed: () => context.read<PaymentProvider>().confirmPayment(payment.id, currentUid),
                      child: const Text('I\'ve Paid'),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Pay Later'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _verificationLabel(String status) {
    return switch (status) {
      'approved' || 'verified_driver' => 'Verified',
      'pending' => 'Pending verification',
      'rejected' => 'Verification rejected',
      _ => 'Not verified',
    };
  }
}