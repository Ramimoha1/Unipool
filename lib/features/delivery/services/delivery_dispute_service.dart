import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unipool/core/constants.dart';
import '../models/delivery_dispute_model.dart';

class DeliveryDisputeService {
  DeliveryDisputeService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _disputes =>
      _firestore.collection(AppCollections.deliveryDisputes);

  /// Creates a dispute for a delivery job.
  Future<void> createDispute(DeliveryDisputeModel dispute) async {
    try {
      final ref = dispute.id.isEmpty ? _disputes.doc() : _disputes.doc(dispute.id);
      final stored = dispute.copyWith(
        id: ref.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await ref.set(stored.toMap());

      // Update the job status to disputed
      await _firestore
          .collection(AppCollections.deliveryJobs)
          .doc(dispute.jobId)
          .update({
        AppFields.jobStatus: DeliveryJobStatuses.disputed,
        AppFields.updatedAt: Timestamp.now(),
      });
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

  /// Streams all disputes filed by a specific seller.
  Stream<List<DeliveryDisputeModel>> getMyDisputes(String sellerId) {
    try {
      return _disputes
          .where(AppFields.sellerId, isEqualTo: sellerId)
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
}
