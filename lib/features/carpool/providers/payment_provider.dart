import 'package:flutter/material.dart';
import '../models/ride_payment_model.dart';
import '../services/payment_service.dart';

class PaymentProvider extends ChangeNotifier {
  PaymentProvider({PaymentService? service}) : _service = service ?? PaymentService();

  final PaymentService _service;

  RidePaymentModel? currentPayment;
  bool isLoading = false;
  String? error;

  Future<void> initializePayment(
    String requestId,
    String bookedByUserId,
    String qrCodeUrl,
    String bankName,
    String accountNumber,
    String accountName,
  ) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service.initializePayment(requestId, bookedByUserId, qrCodeUrl, bankName, accountNumber, accountName);
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePaymentSettings(
    String paymentId,
    String qrCodeUrl,
    String bankName,
    String accountNumber,
    String accountName,
  ) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service.updatePaymentSettings(paymentId, qrCodeUrl, bankName, accountNumber, accountName);
      if (currentPayment?.id == paymentId) {
        currentPayment = await _service.getPayment(currentPayment!.requestId);
      }
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> triggerPayment(String paymentId, String requestId, double totalAmount, Map<String, double> passengerDues) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service.triggerPayment(paymentId, totalAmount, passengerDues);
      currentPayment = await _service.getPayment(requestId);
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> confirmPayment(String paymentId, String userId) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service.confirmPayment(paymentId, userId);
      currentPayment = await _service.getPayment(currentPayment?.requestId ?? '');
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPayment(String requestId) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      currentPayment = await _service.getPayment(requestId);
    } catch (exception) {
      error = exception.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}