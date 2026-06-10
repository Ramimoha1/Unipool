import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/delivery_application_model.dart';
import '../models/delivery_job_model.dart';
import '../services/delivery_service.dart';

class DeliveryProvider extends ChangeNotifier {
  DeliveryProvider({DeliveryService? service})
      : _service = service ?? DeliveryService();

  final DeliveryService _service;

  DeliveryJobModel? currentJob;
  List<DeliveryApplicationModel> applications = [];
  List<DeliveryJobModel> openJobs = [];
  List<DeliveryJobModel> myJobs = [];
  bool isLoading = false;
  String? error;

  StreamSubscription<List<DeliveryJobModel>>? _openJobsSubscription;

  void startOpenJobsStream() {
    _openJobsSubscription?.cancel();
    _openJobsSubscription = _service.getOpenJobs().listen(
      (items) {
        openJobs = items;
        notifyListeners();
      },
      onError: (exception) {
        error = exception.toString();
        notifyListeners();
      },
    );
  }

  Future<void> loadMyJobs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      myJobs = [];
      notifyListeners();
      return;
    }

    isLoading = true;
    error = null;
    notifyListeners();
    try {
      myJobs = await _service.getMyJobs(user.uid);
    } catch (exception) {
      error = exception.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> createJob(DeliveryJobModel job) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final createdId = await _service.createJob(job);
      currentJob = job.copyWith(id: createdId);
      return createdId;
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> applyToJob(
    String jobId,
    String driverId, {
    String notes = '',
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service.applyToJob(jobId, driverId, notes: notes);
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> approveApplication(String jobId, String applicationId) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service.approveApplication(jobId, applicationId);
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> rejectApplication(String jobId, String applicationId) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service.rejectApplication(jobId, applicationId);
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateJobStatus(String jobId, String status) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service.updateJobStatus(jobId, status);
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void loadApplications(String jobId) {
    applications = [];
    notifyListeners();
    _service.getApplications(jobId).listen((items) {
      applications = items;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _openJobsSubscription?.cancel();
    super.dispose();
  }
}
