import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unipool/core/constants.dart';
import '../models/delivery_proof_model.dart';

class DeliveryProofService {
  DeliveryProofService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _proofs(String jobId) {
    return _firestore
        .collection(AppCollections.deliveryJobs)
        .doc(jobId)
        .collection('proofs');
  }

  /// Submits a delivery proof for a specific job.
  Future<void> submitProof(String jobId, DeliveryProofModel proof) async {
    try {
      final proofRef =
          proof.id.isEmpty ? _proofs(jobId).doc() : _proofs(jobId).doc(proof.id);
      final storedProof = proof.copyWith(id: proofRef.id);
      await proofRef.set(storedProof.toMap());

      // Update job status to proof_pending
      await _firestore
          .collection(AppCollections.deliveryJobs)
          .doc(jobId)
          .update({
        AppFields.jobStatus: DeliveryJobStatuses.proofPending,
        AppFields.updatedAt: Timestamp.now(),
      });
    } catch (error) {
      throw Exception('Failed to submit delivery proof: $error');
    }
  }

  /// Streams all proofs for a delivery job.
  Stream<List<DeliveryProofModel>> getProofs(String jobId) {
    try {
      return _proofs(jobId)
          .orderBy(AppFields.createdAt, descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => DeliveryProofModel.fromMap(doc.data(), doc.id))
                .toList(),
          );
    } catch (error) {
      throw Exception('Failed to load delivery proofs: $error');
    }
  }

  /// Reviews (approves or rejects) a delivery proof.
  Future<void> reviewProof(
    String jobId,
    String proofId, {
    required String status,
    required String reviewerId,
  }) async {
    try {
      await _proofs(jobId).doc(proofId).update({
        AppFields.status: status,
        AppFields.reviewedBy: reviewerId,
        AppFields.reviewedAt: Timestamp.now(),
      });

      // If approved, update the job status
      if (status == DeliveryProofStatuses.approved) {
        await _firestore
            .collection(AppCollections.deliveryJobs)
            .doc(jobId)
            .update({
          AppFields.jobStatus: DeliveryJobStatuses.awaitingPayment,
          AppFields.updatedAt: Timestamp.now(),
        });
      }
    } catch (error) {
      throw Exception('Failed to review delivery proof: $error');
    }
  }
}
