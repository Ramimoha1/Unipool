import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unipool/core/constants.dart';
import '../models/delivery_dispute_model.dart';

class DeliveryDisputeService {
  DeliveryDisputeService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _disputes =>
      _firestore.collection(AppCollections.deliveryDisputes);

  /// Creates a dispute for a delivery job and flips the job to `disputed`,
  /// remembering what status it was at so it can be restored on resolution.
  Future<void> createDispute(DeliveryDisputeModel dispute) async {
    try {
      final jobRef =
          _firestore.collection(AppCollections.deliveryJobs).doc(dispute.jobId);
      final jobSnap = await jobRef.get();
      if (!jobSnap.exists) {
        throw Exception('Delivery job not found.');
      }
      final currentJobStatus =
          jobSnap.data()?[AppFields.jobStatus] as String? ?? '';

      // Don't let a job already mid-dispute get a second preDisputeStatus
      // overwritten by another concurrent report — keep the earliest one.
      final alreadyDisputed = currentJobStatus == DeliveryJobStatuses.disputed;

      final ref = dispute.id.isEmpty ? _disputes.doc() : _disputes.doc(dispute.id);
      final stored = dispute.copyWith(
        id: ref.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await ref.set(stored.toMap());

      if (!alreadyDisputed) {
        await jobRef.update({
          AppFields.jobStatus: DeliveryJobStatuses.disputed,
          AppFields.preDisputeStatus: currentJobStatus,
          AppFields.updatedAt: Timestamp.now(),
        });
      }
    } catch (error) {
      throw Exception('Failed to create delivery dispute: $error');
    }
  }

  /// Loads all disputes for a specific delivery job.
  Future<List<DeliveryDisputeModel>> getDisputesForJob(String jobId) async {
    try {
      final snapshot = await _disputes
          .where(AppFields.jobId, isEqualTo: jobId)
          .orderBy(AppFields.createdAt, descending: true)
          .get();
      return snapshot.docs
          .map((doc) => DeliveryDisputeModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (error) {
      throw Exception('Failed to load delivery disputes: $error');
    }
  }

  /// Streams all disputes filed BY this user — works whether they filed
  /// as the seller or the driver. Replaces the old seller-only
  /// getMyDisputes, which silently missed driver-filed disputes.
  Stream<List<DeliveryDisputeModel>> getDisputesFiledByMe(String uid) {
    try {
      return _disputes
          .where(AppFields.filedBy, isEqualTo: uid)
          .orderBy(AppFields.createdAt, descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) =>
                    DeliveryDisputeModel.fromMap(doc.data(), doc.id))
                .toList(),
          );
    } catch (error) {
      throw Exception('Failed to load my disputes: $error');
    }
  }

  /// Admin action: resolves a dispute and restores the job to whatever
  /// status it was at before the dispute was filed (falls back to
  /// in_progress if that was somehow never recorded).
  Future<void> resolveDispute({
    required String disputeId,
    required String jobId,
    required String reviewerId,
  }) async {
    try {
      await _disputes.doc(disputeId).update({
        AppFields.status: DeliveryDisputeStatuses.resolved,
        AppFields.reviewedBy: reviewerId,
        AppFields.updatedAt: Timestamp.now(),
      });

      final jobRef =
          _firestore.collection(AppCollections.deliveryJobs).doc(jobId);
      final jobSnap = await jobRef.get();
      final restoredStatus =
          (jobSnap.data()?[AppFields.preDisputeStatus] as String?)
                  ?.isNotEmpty ==
              true
          ? jobSnap.data()![AppFields.preDisputeStatus] as String
          : DeliveryJobStatuses.inProgress;

      await jobRef.update({
        AppFields.jobStatus: restoredStatus,
        AppFields.preDisputeStatus: '',
        AppFields.updatedAt: Timestamp.now(),
      });
    } catch (error) {
      throw Exception('Failed to resolve delivery dispute: $error');
    }
  }
}