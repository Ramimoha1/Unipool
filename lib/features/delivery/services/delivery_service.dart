import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:unipool/core/constants.dart';
import 'package:unipool/features/carpool/services/notification_service.dart';
import '../models/delivery_application_model.dart';
import '../models/delivery_job_model.dart';

class DeliveryService {
  DeliveryService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    NotificationService? notificationService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _notificationService = notificationService ?? NotificationService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final NotificationService _notificationService;

  CollectionReference<Map<String, dynamic>> get _jobs =>
      _firestore.collection(AppCollections.deliveryJobs);

  CollectionReference<Map<String, dynamic>> _applications(String jobId) =>
      _jobs.doc(jobId).collection('applications');

  // ── Job CRUD ──────────────────────────────────────────────────────────

  /// Creates a new delivery job.
  Future<String> createJob(DeliveryJobModel job) async {
    try {
      final jobRef = job.id.isEmpty ? _jobs.doc() : _jobs.doc(job.id);
      final storedJob = job.copyWith(
        id: jobRef.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await jobRef.set(storedJob.toMap());
      return jobRef.id;
    } catch (error) {
      throw Exception('Failed to create delivery job: $error');
    }
  }

  /// Streams open delivery jobs ordered by creation time.
  Stream<List<DeliveryJobModel>> getOpenJobs() {
    try {
      return _jobs
          .where(AppFields.jobStatus, isEqualTo: DeliveryJobStatuses.open)
          .orderBy(AppFields.createdAt, descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => DeliveryJobModel.fromMap(doc.data(), doc.id))
                .toList(),
          );
    } catch (error) {
      throw Exception('Failed to load delivery jobs: $error');
    }
  }

  /// Loads jobs created by a specific seller.
  Future<List<DeliveryJobModel>> getMyJobs(String userId) async {
    try {
      final snapshot = await _jobs
          .where(AppFields.sellerId, isEqualTo: userId)
          .orderBy(AppFields.createdAt, descending: true)
          .get();
      return snapshot.docs
          .map((doc) => DeliveryJobModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (error) {
      throw Exception('Failed to load my delivery jobs: $error');
    }
  }

  /// Streams a single delivery job by id.
  Stream<DeliveryJobModel> getJobById(String jobId) {
    try {
      return _jobs.doc(jobId).snapshots().map((doc) {
        if (!doc.exists || doc.data() == null) {
          throw Exception('Delivery job not found.');
        }
        return DeliveryJobModel.fromMap(doc.data()!, doc.id);
      });
    } catch (error) {
      throw Exception('Failed to load delivery job: $error');
    }
  }

  /// Updates the status of a delivery job.
  Future<void> updateJobStatus(String jobId, String status) async {
    try {
      final currentUid = _auth.currentUser!.uid;
      final jobDoc = await _jobs.doc(jobId).get();
      if (!jobDoc.exists) {
        throw Exception('Delivery job not found.');
      }
      if ((jobDoc.data()?[AppFields.sellerId] as String?) != currentUid) {
        throw Exception('Only the seller can update the job status.');
      }

      await _jobs.doc(jobId).update({
        AppFields.jobStatus: status,
        AppFields.updatedAt: Timestamp.now(),
      });
    } catch (error) {
      throw Exception('Failed to update delivery job: $error');
    }
  }

  // ── Applications ──────────────────────────────────────────────────────

  /// Submits a driver application for a delivery job.
  Future<void> applyToJob(
    String jobId,
    String driverId, {
    String notes = '',
  }) async {
    try {
      final jobDoc = await _jobs.doc(jobId).get();
      if (!jobDoc.exists) {
        throw Exception('Delivery job not found.');
      }
      final jobData = jobDoc.data()!;
      final jobStatus = jobData[AppFields.jobStatus] as String? ?? '';
      if (jobStatus != DeliveryJobStatuses.open &&
          jobStatus != DeliveryJobStatuses.applicationsOpen) {
        throw Exception('This job is no longer accepting applications.');
      }

      // Check for existing application
      final existing = await _applications(jobId)
          .where(AppFields.driverId, isEqualTo: driverId)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        final existingDoc = existing.docs.first;
        if (existingDoc.data()[AppFields.status] == DeliveryApplicationStatuses.rejected) {
          // Re-apply by updating the existing application to pending
          await existingDoc.reference.update({
            AppFields.status: DeliveryApplicationStatuses.pending,
            AppFields.createdAt: Timestamp.now(),
          });
          return;
        }
        throw Exception('You have already applied to this job.');
      }

      // Check driver verification if required
      if (jobData[AppFields.allowedDrivers] ==
          DeliveryAllowedDrivers.verifiedOnly) {
        final userDoc = await _firestore
            .collection(AppCollections.users)
            .doc(driverId)
            .get();
        final userData = userDoc.data();
        
        final roles = userData?[AppFields.userRoles] as List<dynamic>? ?? [];
        final userRole =
            (userData?[AppFields.userRole] as String?) ??
            (userData?[AppFields.userType] as String?);
            
        final isVerified = roles.contains('verified_driver') || 
                           userRole == 'verified_driver';

        if (!isVerified) {
          throw Exception('You are not a verified driver, this job is only for verified driver. Apply to be verified driver in profile.');
        }
      }

      final appRef = _applications(jobId).doc(driverId);
      final application = DeliveryApplicationModel(
        id: driverId,
        jobId: jobId,
        driverId: driverId,
        status: DeliveryApplicationStatuses.pending,
        notes: notes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await appRef.set(application.toMap());

      // Notify the seller
      final sellerId = jobData[AppFields.sellerId] as String? ?? '';
      if (sellerId.isNotEmpty) {
        await _notificationService.sendFCMToUser(
          sellerId,
          'New driver application',
          'A driver has applied for your delivery job.',
        );
      }
    } catch (error) {
      throw Exception('Failed to apply to delivery job: $error');
    }
  }

  /// Streams applications for a specific delivery job.
  Stream<List<DeliveryApplicationModel>> getApplications(String jobId) {
    try {
      return _applications(jobId)
          .orderBy(AppFields.createdAt, descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) =>
                    DeliveryApplicationModel.fromMap(doc.data(), doc.id))
                .toList(),
          );
    } catch (error) {
      throw Exception('Failed to load applications: $error');
    }
  }

  /// Approves a driver application and assigns the driver to the job.
  Future<void> approveApplication(String jobId, String applicationId) async {
    try {
      final currentUid = _auth.currentUser!.uid;
      final jobDoc = await _jobs.doc(jobId).get();
      if (!jobDoc.exists) {
        throw Exception('Delivery job not found.');
      }
      if ((jobDoc.data()?[AppFields.sellerId] as String?) != currentUid) {
        throw Exception('Only the seller can approve applications.');
      }

      final appDoc = await _applications(jobId).doc(applicationId).get();
      if (!appDoc.exists) {
        throw Exception('Application not found.');
      }
      final appData = appDoc.data()!;
      final driverId = appData[AppFields.driverId] as String;

      final jobRef = _jobs.doc(jobId);
      final appRef = _applications(jobId).doc(applicationId);

      final batch = _firestore.batch();
      
      batch.update(appRef, {
        AppFields.status: DeliveryApplicationStatuses.approved,
        AppFields.updatedAt: Timestamp.now(),
      });
      batch.update(jobRef, {
        AppFields.assignedDriverId: driverId,
        AppFields.sellerApprovedDriverId: driverId,
        AppFields.jobStatus: DeliveryJobStatuses.driverAssigned,
        AppFields.updatedAt: Timestamp.now(),
      });

      // Reject all other pending applications
      final otherAppsSnapshot = await _applications(jobId)
          .where(AppFields.status, isEqualTo: DeliveryApplicationStatuses.pending)
          .get();
          
      for (final doc in otherAppsSnapshot.docs) {
        if (doc.id != applicationId) {
          batch.update(doc.reference, {
            AppFields.status: DeliveryApplicationStatuses.rejected,
            AppFields.updatedAt: Timestamp.now(),
          });
        }
      }

      await batch.commit();

      await _notificationService.sendFCMToUser(
        driverId,
        'Application approved',
        'Your delivery application was approved.',
      );
    } catch (error) {
      throw Exception('Failed to approve application: $error');
    }
  }

  /// Rejects a driver application.
  Future<void> rejectApplication(String jobId, String applicationId) async {
    try {
      final currentUid = _auth.currentUser!.uid;
      final jobDoc = await _jobs.doc(jobId).get();
      if (!jobDoc.exists) {
        throw Exception('Delivery job not found.');
      }
      if ((jobDoc.data()?[AppFields.sellerId] as String?) != currentUid) {
        throw Exception('Only the seller can reject applications.');
      }

      await _applications(jobId).doc(applicationId).update({
        AppFields.status: DeliveryApplicationStatuses.rejected,
        AppFields.updatedAt: Timestamp.now(),
      });
    } catch (error) {
      throw Exception('Failed to reject application: $error');
    }
  }

  /// Assigns a driver directly to a delivery job (without application flow).
  Future<void> assignDriver(String jobId, String driverId) async {
    try {
      final currentUid = _auth.currentUser!.uid;
      final jobDoc = await _jobs.doc(jobId).get();
      if (!jobDoc.exists) {
        throw Exception('Delivery job not found.');
      }
      if ((jobDoc.data()?[AppFields.sellerId] as String?) != currentUid) {
        throw Exception('Only the seller can assign a driver.');
      }

      await _jobs.doc(jobId).update({
        AppFields.assignedDriverId: driverId,
        AppFields.jobStatus: DeliveryJobStatuses.driverAssigned,
        AppFields.updatedAt: Timestamp.now(),
      });

      await _notificationService.sendFCMToUser(
        driverId,
        'Delivery assigned',
        'You have been assigned to a delivery job.',
      );
    } catch (error) {
      throw Exception('Failed to assign driver: $error');
    }
  }

  // ── Driver & Delivery Lifecycle Actions ───────────────────────────────────

  /// Transitions the job status to `in_progress`.
  /// Validates that the caller is the assigned driver.
  Future<void> startDelivery(String jobId) async {
    try {
      final currentUid = _auth.currentUser!.uid;
      final jobDoc = await _jobs.doc(jobId).get();
      if (!jobDoc.exists) {
        throw Exception('Delivery job not found.');
      }
      final data = jobDoc.data()!;
      if ((data[AppFields.assignedDriverId] as String?) != currentUid) {
        throw Exception('Only the assigned driver can start the delivery.');
      }

      await _jobs.doc(jobId).update({
        AppFields.jobStatus: DeliveryJobStatuses.inProgress,
        AppFields.updatedAt: Timestamp.now(),
      });
    } catch (error) {
      throw Exception('Failed to start delivery: $error');
    }
  }

  /// Loads jobs assigned to a specific driver.
  Future<List<DeliveryJobModel>> getDriverJobs(String driverId) async {
    try {
      final snapshot = await _jobs
          .where(AppFields.assignedDriverId, isEqualTo: driverId)
          .get();
      final jobs = snapshot.docs
          .map((doc) => DeliveryJobModel.fromMap(doc.data(), doc.id))
          .toList();
      jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return jobs;
    } catch (error) {
      throw Exception('Failed to load driver jobs: $error');
    }
  }

  /// Loads jobs where the driver's application was rejected
  Future<List<DeliveryJobModel>> getRejectedDriverJobs(String driverId) async {
    try {
      // Get all active jobs
      final snapshot = await _jobs
          .where(AppFields.jobStatus, whereIn: [
            DeliveryJobStatuses.open,
            DeliveryJobStatuses.applicationsOpen,
          ])
          .get();

      final jobs = <DeliveryJobModel>[];
      for (final doc in snapshot.docs) {
        // Query the applications subcollection
        final apps = await _applications(doc.id)
            .where(AppFields.driverId, isEqualTo: driverId)
            .limit(1)
            .get();
            
        if (apps.docs.isNotEmpty && 
            apps.docs.first.data()[AppFields.status] == DeliveryApplicationStatuses.rejected) {
          final job = DeliveryJobModel.fromMap(doc.data(), doc.id);
          jobs.add(job.copyWith(jobStatus: DeliveryApplicationStatuses.rejected));
        }
      }
      return jobs;
    } catch (error) {
      debugPrint('Failed to load rejected jobs: $error');
      return [];
    }
  }

  /// Streams jobs assigned to a specific driver.
  Stream<List<DeliveryJobModel>> getDriverJobsStream(String driverId) {
    try {
      return _jobs
          .where(AppFields.assignedDriverId, isEqualTo: driverId)
          .snapshots()
          .map((snapshot) {
            final jobs = snapshot.docs
                .map((doc) => DeliveryJobModel.fromMap(doc.data(), doc.id))
                .toList();
            jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return jobs;
          });
    } catch (error) {
      throw Exception('Failed to stream driver jobs: $error');
    }
  }

  /// Transitions the job status to `completed`.
  /// Validates that the caller is the seller.
  Future<void> completeJob(String jobId) async {
    try {
      final currentUid = _auth.currentUser!.uid;
      final jobDoc = await _jobs.doc(jobId).get();
      if (!jobDoc.exists) {
        throw Exception('Delivery job not found.');
      }
      final data = jobDoc.data()!;
      if ((data[AppFields.sellerId] as String?) != currentUid) {
        throw Exception('Only the seller can mark the job as completed.');
      }

      await _jobs.doc(jobId).update({
        AppFields.jobStatus: DeliveryJobStatuses.completed,
        AppFields.updatedAt: Timestamp.now(),
      });

      // Notify the driver
      final driverId = data[AppFields.assignedDriverId] as String? ?? '';
      if (driverId.isNotEmpty) {
        await _notificationService.sendFCMToUser(
          driverId,
          'Delivery Completed',
          'The seller has marked your delivery job as completed.',
        );
      }
    } catch (error) {
      throw Exception('Failed to complete delivery job: $error');
    }
  }
}

