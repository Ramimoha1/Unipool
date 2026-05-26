import 'package:flutter/material.dart';
import '../models/ride_payment_model.dart';
import '../services/payment_service.dart';

class PaymentProvider extends ChangeNotifier {
  PaymentProvider({PaymentService? service}) : _service = service ?? PaymentService();

  final PaymentService _service;

  RidePaymentModel? currentPayment;
  bool isLoading = false;
  String? error;

  Future<void> triggerPayment(String requestId) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service.triggerPayment(requestId);
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