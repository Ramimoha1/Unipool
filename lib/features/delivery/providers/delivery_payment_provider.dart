import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../models/delivery_payment_model.dart';
import '../services/delivery_payment_service.dart';

class DeliveryPaymentProvider extends ChangeNotifier {
  DeliveryPaymentProvider({DeliveryPaymentService? service})
      : _service = service ?? DeliveryPaymentService();

  final DeliveryPaymentService _service;

  DeliveryPaymentModel? currentPayment;
  bool isLoading = false;
  String? error;

  Future<void> triggerPayment(String jobId) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service.triggerPayment(jobId);
      currentPayment = await _service.getPayment(jobId);
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
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
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service.submitPaymentProof(
        paymentId: paymentId,
        jobId: jobId,
        sellerId: sellerId,
        fileBytes: fileBytes,
        fileName: fileName,
        mimeType: mimeType,
      );
      currentPayment =
          await _service.getPayment(currentPayment?.jobId ?? jobId);
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> confirmPaymentReceived({
    required String paymentId,
    required String jobId,
    required String driverId,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service.confirmPaymentReceived(
        paymentId: paymentId,
        jobId: jobId,
        driverId: driverId,
      );
      currentPayment = await _service.getPayment(jobId);
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPayment(String jobId) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      currentPayment = await _service.getPayment(jobId);
      if (currentPayment != null) {
        final hasDetails = currentPayment!.bankName.isNotEmpty ||
            currentPayment!.accountNumber.isNotEmpty ||
            currentPayment!.qrCodeUrl.isNotEmpty;
        if (!hasDetails) {
          await _service.syncPaymentBankDetails(jobId);
          currentPayment = await _service.getPayment(jobId);
        }
      }
    } catch (exception) {
      error = exception.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
