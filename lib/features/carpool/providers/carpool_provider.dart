import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/carpool_applicant_model.dart';
import '../models/carpool_request_model.dart';
import '../services/carpool_service.dart';

class CarpoolProvider extends ChangeNotifier {
  CarpoolProvider({CarpoolService? service}) : _service = service ?? CarpoolService();

  final CarpoolService _service;

  CarpoolRequestModel? currentRequest;
  List<CarpoolApplicantModel> applicants = [];
  List<CarpoolRequestModel> openRequests = [];
  List<CarpoolRequestModel> nearbyRequests = [];
  List<CarpoolRequestModel> myRequests = [];
  bool isLoading = false;
  String? error;

  StreamSubscription<List<CarpoolRequestModel>>? _openRequestsSubscription;

  Future<void> loadNearbyRequests(double lat, double lng, {double radiusKm = 5}) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      nearbyRequests = await _service.getNearbyRequests(lat, lng, radiusKm);
    } catch (exception) {
      error = exception.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void startOpenRequestsStream() {
    _openRequestsSubscription?.cancel();
    _openRequestsSubscription = _service.getOpenRequests().listen((items) {
      openRequests = items;
      notifyListeners();
    }, onError: (exception) {
      error = exception.toString();
      notifyListeners();
    });
  }

  Future<void> loadMyRequests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      myRequests = [];
      notifyListeners();
      return;
    }

    isLoading = true;
    error = null;
    notifyListeners();
    try {
      myRequests = await _service.getMyRequests(user.uid);
    } catch (exception) {
      error = exception.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createRequest(CarpoolRequestModel request) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service.createRequest(request);
      currentRequest = request.copyWith(id: request.id.isEmpty ? '' : request.id);
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> applyToRequest(String requestId, String userId, String role) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service.applyToRequest(requestId, userId, role);
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> acceptApplicant(String requestId, String applicantId, String role) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service.acceptApplicant(requestId, applicantId, role);
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> rejectApplicant(String requestId, String applicantId) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service.rejectApplicant(requestId, applicantId);
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateStatus(String requestId, String status) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service.updateRequestStatus(requestId, status);
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void loadApplicants(String requestId) {
    applicants = [];
    notifyListeners();
    _service.getApplicants(requestId).listen((items) {
      applicants = items;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _openRequestsSubscription?.cancel();
    super.dispose();
  }
}