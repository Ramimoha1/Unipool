import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (payment.qrCodeUrl.isNotEmpty)
                    Image.network(payment.qrCodeUrl, height: 220)
                  else
                    const Center(child: Text('QR code not available yet.')),
                  const SizedBox(height: 16),
                  Center(child: Text('Scan to pay ${payment.splitAmount.toStringAsFixed(2)}')),
                  const SizedBox(height: 24),
                  const PaymentBanner(message: 'Confirm payment once you have paid.'),
                  const SizedBox(height: 16),
                  ...members.map((memberId) {
                    final confirmed = payment.confirmedBy.contains(memberId);
                    return ListTile(
                      leading: Icon(confirmed ? Icons.check_circle : Icons.schedule, color: confirmed ? Colors.green : Colors.grey),
                      title: Text(memberId),
                      subtitle: Text(confirmed ? 'Paid' : 'Pending'),
                    );
                  }),
                  if (!payment.confirmedBy.contains(currentUid))
                    FilledButton(
                      onPressed: () => context.read<PaymentProvider>().confirmPayment(payment.id, currentUid),
                      child: const Text('I\'ve Paid'),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}