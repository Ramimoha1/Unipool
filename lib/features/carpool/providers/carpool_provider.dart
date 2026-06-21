import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/carpool_applicant_model.dart';
import '../models/carpool_request_model.dart';
import '../services/carpool_service.dart';

class CarpoolProvider extends ChangeNotifier {
  CarpoolProvider({CarpoolService? service})
    : _service = service ?? CarpoolService();

  final CarpoolService _service;

  CarpoolRequestModel? currentRequest;
  List<CarpoolApplicantModel> applicants = [];
  List<CarpoolRequestModel> openRequests = [];
  List<CarpoolRequestModel> nearbyRequests = [];
  List<CarpoolRequestModel> myRequests = [];
  List<CarpoolRequestModel> activeCarpools = [];
  bool isLoading = false;
  String? error;

  bool get hasActiveCarpool => activeCarpools.isNotEmpty;

  StreamSubscription<List<CarpoolRequestModel>>? _openRequestsSubscription;

  Future<void> loadNearbyRequests(
    double lat,
    double lng, {
    double radiusKm = 5,
  }) async {
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
    _openRequestsSubscription = _service.getOpenRequests().listen(
      (items) {
        openRequests = items;
        notifyListeners();
      },
      onError: (exception) {
        error = exception.toString();
        notifyListeners();
      },
    );
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

  Future<void> loadActiveCarpools() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      activeCarpools = [];
      notifyListeners();
      return;
    }

    isLoading = true;
    error = null;
    notifyListeners();
    try {
      activeCarpools = await _service.getActiveCarpoolsForUser(user.uid);
    } catch (exception) {
      error = exception.toString();
      activeCarpools = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> leaveGroup(String requestId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service.leaveGroup(requestId, user.uid);
      // Refresh active carpools + my requests after leaving
      await loadActiveCarpools();
      await loadMyRequests();
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> kickMember(String requestId, String targetUserId) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service.kickMember(requestId, targetUserId);
      await loadMyRequests();
      await loadActiveCarpools();
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> createRequest(CarpoolRequestModel request, {bool isCreatorDriver = false}) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final createdId = await _service.createRequest(request, isCreatorDriver: isCreatorDriver);
      currentRequest = request.copyWith(id: createdId);
      return createdId;
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> applyToRequest(
    String requestId,
    String userId,
    String role,
  ) async {
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

  Future<void> withdrawApplication(String applicantId) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service.withdrawApplication(applicantId);
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> acceptApplicant(
    String requestId,
    String applicantId,
    String role,
  ) async {
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

  Future<void> updateRequestSettings(String requestId, Map<String, dynamic> updates) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service.updateRequestSettings(requestId, updates);
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> transferCreator(String requestId, String newCreatorId) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service.transferCreator(requestId, newCreatorId);
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
    _service.getApplicants(requestId).listen(
      (items) {
        applicants = items;
        notifyListeners();
      },
      onError: (exception) {
        error = exception.toString();
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _openRequestsSubscription?.cancel();
    super.dispose();
  }
}
