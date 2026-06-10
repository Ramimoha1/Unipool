import 'dart:async';

import 'package:flutter/material.dart';
import '../models/delivery_proof_model.dart';
import '../services/delivery_proof_service.dart';

class DeliveryProofProvider extends ChangeNotifier {
  DeliveryProofProvider({DeliveryProofService? service})
      : _service = service ?? DeliveryProofService();

  final DeliveryProofService _service;
  StreamSubscription<List<DeliveryProofModel>>? _subscription;

  List<DeliveryProofModel> proofs = [];
  bool isLoading = false;
  String? error;

  void subscribeToProofs(String jobId) {
    isLoading = true;
    notifyListeners();

    _subscription?.cancel();
    _subscription = _service.getProofs(jobId).listen(
      (items) {
        proofs = items;
        isLoading = false;
        notifyListeners();
      },
      onError: (exception) {
        error = exception.toString();
        isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> submitProof(String jobId, DeliveryProofModel proof) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service.submitProof(jobId, proof);
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reviewProof(
    String jobId,
    String proofId, {
    required String status,
    required String reviewerId,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service.reviewProof(
        jobId,
        proofId,
        status: status,
        reviewerId: reviewerId,
      );
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
