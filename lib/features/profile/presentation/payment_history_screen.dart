import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:unipool/core/constants.dart';
import 'package:unipool/features/carpool/models/ride_payment_model.dart';
import 'package:unipool/features/carpool/screens/payment_screen.dart';

class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment History')),
      body: uid == null
          ? const Center(child: Text('Not logged in'))
          : FutureBuilder<List<RidePaymentModel>>(
              future: () async {
                if (uid == null) return <RidePaymentModel>[];
                final groupsSnapshot = await FirebaseFirestore.instance
                    .collection(AppCollections.carpoolGroups)
                    .where('member_ids', arrayContains: uid)
                    .get();
                if (groupsSnapshot.docs.isEmpty) return <RidePaymentModel>[];
                
                final requestIds = groupsSnapshot.docs.map((d) => d.id).toList();
                final List<RidePaymentModel> allPayments = [];
                
                for (var i = 0; i < requestIds.length; i += 10) {
                  final chunk = requestIds.sublist(
                    i, 
                    i + 10 > requestIds.length ? requestIds.length : i + 10
                  );
                  final paymentsSnapshot = await FirebaseFirestore.instance
                      .collection(AppCollections.ridePayments)
                      .where('request_id', whereIn: chunk)
                      .get();
                  allPayments.addAll(paymentsSnapshot.docs.map((d) => RidePaymentModel.fromMap(d.data(), d.id)));
                }
                
                final myPayments = allPayments.where((p) {
                  final isPayer = p.passengerDues.containsKey(uid) && p.passengerDues[uid]! > 0;
                  final isPayee = p.bookedByUserId == uid;
                  return isPayer || isPayee;
                }).toList();
                
                myPayments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                return myPayments;
              }(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final myPayments = snapshot.data ?? [];

                if (myPayments.isEmpty) {
                  return const Center(child: Text('No payment history found.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: myPayments.length,
                  itemBuilder: (context, index) {
                    final payment = myPayments[index];
                    final isPayee = payment.bookedByUserId == uid;
                    final due = payment.passengerDues[uid] ?? 0.0;
                    final isPayer = due > 0;
                    final hasPaid = payment.confirmedBy.contains(uid);

                    String roleText = isPayee ? 'Receiving Payment' : 'Paying';
                    String amountText = isPayee 
                      ? 'Total Expected: RM ${payment.totalAmount.toStringAsFixed(2)}'
                      : 'Due: RM ${due.toStringAsFixed(2)}';
                    String statusText = isPayee
                      ? '${payment.confirmedBy.length} paid'
                      : (hasPaid ? 'Paid' : 'Unpaid');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPayee ? Colors.green.withValues(alpha: 0.2) : (hasPaid ? Colors.blue.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2)),
                          child: Icon(
                            isPayee ? Icons.download : (hasPaid ? Icons.check : Icons.payment),
                            color: isPayee ? Colors.green : (hasPaid ? Colors.blue : Colors.orange),
                          ),
                        ),
                        title: Text(roleText, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(amountText),
                            Text('Status: $statusText'),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        isThreeLine: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaymentScreen(requestId: payment.requestId),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
