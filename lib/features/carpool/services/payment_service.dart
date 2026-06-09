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

  /// Creates a payment document for a completed carpool group.
  Future<void> triggerPayment(String requestId) async {
    try {
      final requestDoc = await _requests.doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Request not found.');
      }

      final requestData = requestDoc.data()!;
      if (requestData[AppFields.status] != CarpoolRequestStatuses.inProgress) {
        throw Exception(
          'Payment can only be triggered when the request is in progress.',
        );
      }

      final currentUid = _auth.currentUser!.uid;
      if (requestData[AppFields.creatorId] != currentUid) {
        throw Exception('Only the request creator can trigger payment.');
      }

      final groupQuery = await _groups
          .where(AppFields.requestId, isEqualTo: requestId)
          .limit(1)
          .get();
      if (groupQuery.docs.isEmpty) {
        throw Exception('Carpool group not found.');
      }

      final group = groupQuery.docs.first.data();
      final members = (group[AppFields.memberIds] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList();
      final bookedByUserId =
          (group[AppFields.driverId] as String?)?.isNotEmpty == true
          ? group[AppFields.driverId] as String
          : requestData[AppFields.creatorId] as String;

      final userDoc = await _firestore
          .collection(AppCollections.users)
          .doc(bookedByUserId)
          .get();
      final userData = userDoc.data();
      var qrCodeUrl =
          (userData?[AppFields.userQrCodeUrl] as String?) ??
          (userData?[AppFields.userQrCodeUrlSnake] as String?) ??
          '';
      if (qrCodeUrl.isEmpty &&
          bookedByUserId != requestData[AppFields.creatorId]) {
        final creatorDoc = await _firestore
            .collection(AppCollections.users)
            .doc(requestData[AppFields.creatorId])
            .get();
        final creatorData = creatorDoc.data();
        qrCodeUrl =
            (creatorData?[AppFields.userQrCodeUrl] as String?) ??
            (creatorData?[AppFields.userQrCodeUrlSnake] as String?) ??
            '';
      }

      final paymentRef = _payments.doc();
      final payment = RidePaymentModel(
        id: paymentRef.id,
        requestId: requestId,
        bookedByUserId: bookedByUserId,
        qrCodeUrl: qrCodeUrl,
        totalAmount: 0,
        splitAmount: 0,
        status: CarpoolPaymentStatuses.pending,
        confirmedBy: const [],
        createdAt: DateTime.now(),
      );
      await paymentRef.set(payment.toMap());

      for (final memberId in members) {
        await _notificationService.sendFCMToUser(
          memberId,
          'Payment ready',
          'A carpool payment is ready for your group.',
        );
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
