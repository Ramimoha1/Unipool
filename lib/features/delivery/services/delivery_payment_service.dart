import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:unipool/core/constants.dart';
import 'package:unipool/features/carpool/services/notification_service.dart';
import '../models/delivery_payment_model.dart';

class DeliveryPaymentService {
  DeliveryPaymentService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    NotificationService? notificationService,
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _notificationService = notificationService ?? NotificationService(),
        _functions = functions ?? FirebaseFunctions.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final NotificationService _notificationService;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _jobs =>
      _firestore.collection(AppCollections.deliveryJobs);
  CollectionReference<Map<String, dynamic>> get _payments =>
      _firestore.collection(AppCollections.deliveryPayments);

  bool _paymentHasDetails(DeliveryPaymentModel payment) {
    return payment.bankName.isNotEmpty ||
        payment.accountNumber.isNotEmpty ||
        payment.qrCodeUrl.isNotEmpty;
  }

  bool _snapshotHasDetails(Map<String, dynamic>? snapshot) {
    if (snapshot == null) return false;
    return (snapshot[AppFields.bankName] as String? ?? '').isNotEmpty ||
        (snapshot[AppFields.accountNumber] as String? ?? '').isNotEmpty ||
        (snapshot[AppFields.qrCodeUrl] as String? ?? '').isNotEmpty;
  }

  Future<Map<String, dynamic>?> _loadApplicationBankSnapshot(
    String jobId,
    String driverId,
  ) async {
    final appDoc =
        await _jobs.doc(jobId).collection('applications').doc(driverId).get();
    if (!appDoc.exists) return null;
    return appDoc.data()?[AppFields.payeeBankSnapshot] as Map<String, dynamic>?;
  }

  Future<void> _copyBankDetailsViaFunction(
    String driverId,
    String paymentId,
  ) async {
    await _functions
        .httpsCallable(FirebaseFunctionNames.copyPayeeBankDetails)
        .call(<String, dynamic>{
      'payeeId': driverId,
      'paymentCollection': AppCollections.deliveryPayments,
      'paymentId': paymentId,
    });
  }

  Future<void> _writeSnapshot(
    String paymentId,
    Map<String, dynamic> snapshot,
  ) async {
    await _payments.doc(paymentId).update({
      AppFields.payeeBankSnapshot: snapshot,
    });
  }

  /// Creates or repairs a payment document when a delivery proof is approved.
  Future<void> triggerPayment(String jobId) async {
    try {
      final jobDoc = await _jobs.doc(jobId).get();
      if (!jobDoc.exists) {
        throw Exception('Delivery job not found.');
      }

      final jobData = jobDoc.data()!;
      if (jobData[AppFields.jobStatus] != DeliveryJobStatuses.awaitingPayment) {
        throw Exception(
          'Payment can only be triggered when the job is awaiting payment.',
        );
      }

      final sellerId = jobData[AppFields.sellerId] as String? ?? '';
      final driverId = jobData[AppFields.assignedDriverId] as String? ?? '';
      if (driverId.isEmpty) {
        throw Exception('No driver assigned to this job.');
      }

      final currentUid = _auth.currentUser?.uid;
      if (currentUid != null && currentUid != sellerId) {
        throw Exception('Only the seller can trigger payment.');
      }

      final existing = await getPayment(jobId);
      if (existing != null && _paymentHasDetails(existing)) {
        return;
      }

      final applicationSnapshot =
          await _loadApplicationBankSnapshot(jobId, driverId);
      final totalAmount = (jobData[AppFields.price] as num?)?.toDouble() ?? 0;

      if (existing != null) {
        await _fillMissingSnapshot(
          paymentId: existing.id,
          driverId: driverId,
          applicationSnapshot: applicationSnapshot,
        );
        return;
      }

      final paymentRef = _payments.doc();
      final paymentMap = DeliveryPaymentModel(
        id: paymentRef.id,
        jobId: jobId,
        sellerId: sellerId,
        bookedByUserId: driverId,
        qrCodeUrl: '',
        totalAmount: totalAmount,
        status: DeliveryPaymentStatuses.pending,
        confirmedBy: const [],
        createdAt: DateTime.now(),
      ).toMap();

      if (_snapshotHasDetails(applicationSnapshot)) {
        paymentMap[AppFields.payeeBankSnapshot] = applicationSnapshot;
      }

      await paymentRef.set(paymentMap);

      if (!_snapshotHasDetails(applicationSnapshot)) {
        try {
          await _copyBankDetailsViaFunction(driverId, paymentRef.id);
        } catch (_) {
          // Payment doc exists; sync can retry when the screen opens.
        }
      }

      if (sellerId.isNotEmpty) {
        await _notificationService.sendFCMToUser(
          sellerId,
          'Payment ready',
          'Please pay the driver for your delivery job.',
        );
      }
      await _notificationService.sendFCMToUser(
        driverId,
        'Payment pending',
        'The seller will pay you for this delivery.',
      );
    } catch (error) {
      throw Exception('Failed to trigger delivery payment: $error');
    }
  }

  Future<void> _fillMissingSnapshot({
    required String paymentId,
    required String driverId,
    required Map<String, dynamic>? applicationSnapshot,
  }) async {
    if (_snapshotHasDetails(applicationSnapshot)) {
      await _writeSnapshot(paymentId, applicationSnapshot!);
      return;
    }

    try {
      await _copyBankDetailsViaFunction(driverId, paymentId);
    } catch (_) {
      // Leave empty; syncPaymentBankDetails can retry on screen load.
    }
  }

  /// Repairs payments that were created without a bank snapshot.
  Future<void> syncPaymentBankDetails(String jobId) async {
    final payment = await getPayment(jobId);
    if (payment == null || _paymentHasDetails(payment)) return;

    final applicationSnapshot = await _loadApplicationBankSnapshot(
      jobId,
      payment.bookedByUserId,
    );

    await _fillMissingSnapshot(
      paymentId: payment.id,
      driverId: payment.bookedByUserId,
      applicationSnapshot: applicationSnapshot,
    );
  }

  Future<DeliveryPaymentModel?> getPayment(String jobId) async {
    try {
      final snapshot = await _payments
          .where(AppFields.jobId, isEqualTo: jobId)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        return null;
      }
      final doc = snapshot.docs.first;
      return DeliveryPaymentModel.fromMap(doc.data(), doc.id);
    } catch (error) {
      throw Exception('Failed to load delivery payment: $error');
    }
  }

  Future<void> submitPaymentProof({
    required String paymentId,
    required String jobId,
    required String sellerId,
    required Uint8List fileBytes,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      if (_auth.currentUser?.uid != sellerId) {
        throw Exception('Only the seller can submit payment proof.');
      }

      final paymentDoc = await _payments.doc(paymentId).get();
      if (!paymentDoc.exists) {
        throw Exception('Payment record not found.');
      }

      final payment = DeliveryPaymentModel.fromMap(
        paymentDoc.data()!,
        paymentDoc.id,
      );
      if (payment.isSettled) {
        throw Exception('Payment has already been submitted.');
      }

      final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
      final storageRef = _storage
          .ref()
          .child('delivery_payment_proofs')
          .child(jobId)
          .child('${DateTime.now().millisecondsSinceEpoch}_$safeName');

      await storageRef.putData(
        fileBytes,
        SettableMetadata(contentType: mimeType),
      );
      final proofUrl = await storageRef.getDownloadURL();

      await _payments.doc(paymentId).update({
        AppFields.paymentProofUrl: proofUrl,
        AppFields.paymentProofMimeType: mimeType,
        AppFields.paidAt: FieldValue.serverTimestamp(),
        AppFields.confirmedBy: FieldValue.arrayUnion([sellerId]),
        AppFields.paymentStatus: DeliveryPaymentStatuses.settled,
      });

      await _notificationService.sendFCMToUser(
        payment.bookedByUserId,
        'Payment received',
        'The seller has paid you. View the payment proof in the app.',
      );
    } catch (error) {
      throw Exception('Failed to submit payment proof: $error');
    }
  }

  Future<void> confirmPaymentReceived({
    required String paymentId,
    required String jobId,
    required String driverId,
  }) async {
    try {
      if (_auth.currentUser?.uid != driverId) {
        throw Exception('Only the driver can confirm payment receipt.');
      }

      final paymentDoc = await _payments.doc(paymentId).get();
      if (!paymentDoc.exists) {
        throw Exception('Payment record not found.');
      }

      final payment = DeliveryPaymentModel.fromMap(
        paymentDoc.data()!,
        paymentDoc.id,
      );
      if (!payment.isSettled) {
        throw Exception(
          'Payment proof has not been submitted by the seller yet.',
        );
      }
      if (payment.driverConfirmedPayment) {
        return;
      }
      if (payment.bookedByUserId != driverId) {
        throw Exception('You are not the payee for this payment.');
      }

      await _payments.doc(paymentId).update({
        AppFields.driverConfirmedAt: FieldValue.serverTimestamp(),
      });

      final sellerId = payment.sellerId;
      if (sellerId.isNotEmpty) {
        await _notificationService.sendFCMToUser(
          sellerId,
          'Payment confirmed',
          'The driver confirmed they received payment. They can now complete the job.',
        );
      }
    } catch (error) {
      throw Exception('Failed to confirm payment receipt: $error');
    }
  }
}
