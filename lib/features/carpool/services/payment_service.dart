import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:unipool/core/constants.dart';
import '../models/ride_payment_model.dart';
import 'notification_service.dart';

class PaymentService {
  PaymentService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    NotificationService? notificationService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _notificationService = notificationService ?? NotificationService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final NotificationService _notificationService;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection(AppCollections.carpoolRequests);
  CollectionReference<Map<String, dynamic>> get _payments =>
      _firestore.collection(AppCollections.ridePayments);
  CollectionReference<Map<String, dynamic>> get _groups =>
      _firestore.collection(AppCollections.carpoolGroups);

  /// Initializes a payment document for a newly created carpool request.
  Future<void> initializePayment(
    String requestId,
    String bookedByUserId,
    String qrCodeUrl,
    String bankName,
    String accountNumber,
    String accountName,
  ) async {
    try {
      final paymentRef = _payments.doc();
      final payment = RidePaymentModel(
        id: paymentRef.id,
        requestId: requestId,
        bookedByUserId: bookedByUserId,
        qrCodeUrl: qrCodeUrl,
        bankName: bankName,
        accountNumber: accountNumber,
        accountName: accountName,
        totalAmount: 0,
        passengerDues: {},
        status: CarpoolPaymentStatuses.pending,
        confirmedBy: const [],
        createdAt: DateTime.now(),
      );
      await paymentRef.set(payment.toMap());
    } catch (error) {
      throw Exception('Failed to initialize payment: $error');
    }
  }

  /// Updates the payment settings for a request.
  Future<void> updatePaymentSettings(
    String paymentId,
    String qrCodeUrl,
    String bankName,
    String accountNumber,
    String accountName,
  ) async {
    try {
      await _payments.doc(paymentId).update({
        AppFields.qrCodeUrl: qrCodeUrl,
        'bankName': bankName,
        'accountNumber': accountNumber,
        'accountName': accountName,
      });
    } catch (error) {
      throw Exception('Failed to update payment settings: $error');
    }
  }

  /// Triggers the payment to start (moves status to awaiting_payment and sets dues).
  Future<void> triggerPayment(String paymentId, double totalAmount, Map<String, double> passengerDues) async {
    try {
      final doc = await _payments.doc(paymentId).get();
      if (!doc.exists) {
        throw Exception('Payment not found.');
      }

      await _payments.doc(paymentId).update({
        AppFields.totalAmount: totalAmount,
        'passengerDues': passengerDues,
        AppFields.paymentStatus: CarpoolPaymentStatuses.awaitingPayment, // Ensure you use the correct constant
      });

      // Send notifications to payers
      for (final memberId in passengerDues.keys) {
        if (passengerDues[memberId]! > 0) {
          await _notificationService.sendFCMToUser(
            memberId,
            'Payment ready',
            'A carpool payment is ready for your group.',
          );
        }
      }
    } catch (error) {
      throw Exception('Failed to trigger payment: $error');
    }
  }

  /// Loads the latest payment associated with a carpool request.
  Future<RidePaymentModel?> getPayment(String requestId) async {
    try {
      final snapshot = await _payments
          .where(AppFields.requestId, isEqualTo: requestId)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        return null;
      }
      final doc = snapshot.docs.first;
      return RidePaymentModel.fromMap(doc.data(), doc.id);
    } catch (error) {
      throw Exception('Failed to load payment: $error');
    }
  }

  /// Confirms that the current user has paid.
  Future<void> confirmPayment(String paymentId, String userId) async {
    try {
      if (_auth.currentUser?.uid != userId) {
        throw Exception('You can only confirm payment for your own account.');
      }

      await _payments.doc(paymentId).update({
        AppFields.confirmedBy: FieldValue.arrayUnion([userId]),
      });
    } catch (error) {
      throw Exception('Failed to confirm payment: $error');
    }
  }
}
