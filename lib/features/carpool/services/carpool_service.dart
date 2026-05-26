import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:unipool/core/constants.dart';
import '../models/carpool_applicant_model.dart';
import '../models/carpool_group_model.dart';
import '../models/carpool_request_model.dart';
import 'notification_service.dart';

class CarpoolService {
  CarpoolService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    NotificationService? notificationService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _notificationService = notificationService ?? NotificationService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final NotificationService _notificationService;

  CollectionReference<Map<String, dynamic>> get _requests => _firestore.collection(AppCollections.carpoolRequests);
  CollectionReference<Map<String, dynamic>> get _applicants => _firestore.collection(AppCollections.carpoolApplicants);
  CollectionReference<Map<String, dynamic>> get _groups => _firestore.collection(AppCollections.carpoolGroups);

  /// Creates a new carpool request and seeds its group document.
  Future<void> createRequest(CarpoolRequestModel request) async {
    try {
      final requestRef = request.id.isEmpty ? _requests.doc() : _requests.doc(request.id);
      final groupRef = _groups.doc(requestRef.id);
      final storedRequest = request.copyWith(id: requestRef.id, createdAt: request.createdAt);

      await _firestore.runTransaction((transaction) async {
        transaction.set(requestRef, storedRequest.toMap());
        transaction.set(groupRef, CarpoolGroupModel(
          id: groupRef.id,
          requestId: requestRef.id,
          adminId: request.creatorId,
          memberIds: [request.creatorId],
          createdAt: DateTime.now(),
        ).toMap());
      });
    } catch (error) {
      throw Exception('Failed to create request: $error');
    }
  }

  /// Streams open carpool requests.
  Stream<List<CarpoolRequestModel>> getOpenRequests() {
    try {
      return _requests
          .where(AppFields.status, isEqualTo: CarpoolRequestStatuses.open)
          .orderBy(AppFields.createdAt, descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => CarpoolRequestModel.fromMap(doc.data(), doc.id)).toList());
    } catch (error) {
      throw Exception('Failed to load requests: $error');
    }
  }

  /// Loads requests created by the current user.
  Future<List<CarpoolRequestModel>> getMyRequests(String userId) async {
    try {
      final snapshot = await _requests
          .where(AppFields.creatorId, isEqualTo: userId)
          .orderBy(AppFields.createdAt, descending: true)
          .get();
      return snapshot.docs.map((doc) => CarpoolRequestModel.fromMap(doc.data(), doc.id)).toList();
    } catch (error) {
      throw Exception('Failed to load my requests: $error');
    }
  }

  /// Loads a request by its document id.
  Stream<CarpoolRequestModel> getRequestById(String requestId) {
    try {
      return _requests.doc(requestId).snapshots().map((doc) {
        if (!doc.exists || doc.data() == null) {
          throw Exception('Request not found.');
        }
        return CarpoolRequestModel.fromMap(doc.data()!, doc.id);
      });
    } catch (error) {
      throw Exception('Failed to load request: $error');
    }
  }

  /// Updates the status of a request after verifying the creator.
  Future<void> updateRequestStatus(String requestId, String status) async {
    try {
      final currentUid = _auth.currentUser!.uid;
      final requestDoc = await _requests.doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Request not found.');
      }
      if ((requestDoc.data()?[AppFields.creatorId] as String?) != currentUid) {
        throw Exception('Only the creator can update the request status.');
      }

      await _requests.doc(requestId).update({AppFields.status: status});
    } catch (error) {
      throw Exception('Failed to update request: $error');
    }
  }

  /// Deletes a request if the current user is the creator.
  Future<void> deleteRequest(String requestId) async {
    try {
      final currentUid = _auth.currentUser!.uid;
      final requestDoc = await _requests.doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Request not found.');
      }
      if ((requestDoc.data()?[AppFields.creatorId] as String?) != currentUid) {
        throw Exception('Only the creator can delete the request.');
      }

      await _requests.doc(requestId).delete();
    } catch (error) {
      throw Exception('Failed to delete request: $error');
    }
  }

  /// Lets a user apply to a request with the requested role.
  Future<void> applyToRequest(String requestId, String userId, String role) async {
    try {
      final requestDoc = await _requests.doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Request not found.');
      }

      final requestData = requestDoc.data()!;
      if (requestData[AppFields.rideType] == CarpoolRideTypes.grab && role == CarpoolApplicantRoles.driver) {
        throw Exception('Driver applications are not allowed for grab rides.');
      }

      final existingApplication = await _applicants
          .where(AppFields.requestId, isEqualTo: requestId)
          .where(AppFields.userId, isEqualTo: userId)
          .limit(1)
          .get();
      if (existingApplication.docs.isNotEmpty) {
        throw Exception('You have already applied to this request.');
      }

      if (role == CarpoolApplicantRoles.driver && requestData[AppFields.allowUnverifiedDriver] == false) {
        final userDoc = await _firestore.collection(AppCollections.users).doc(userId).get();
        final userData = userDoc.data();
        final userRole = (userData?[AppFields.userRole] as String?) ?? (userData?[AppFields.userType] as String?);
        if (userRole != 'verified_driver') {
          throw Exception('Only verified drivers can apply for this request.');
        }
      }

      await _applicants.doc().set(
        CarpoolApplicantModel(
          id: '',
          requestId: requestId,
          userId: userId,
          applicantRole: role,
          status: CarpoolApplicantStatuses.pending,
          appliedAt: DateTime.now(),
        ).toMap(),
      );
    } catch (error) {
      throw Exception('Failed to submit application: $error');
    }
  }

  /// Accepts an applicant and updates request seats, group membership, and notifications.
  Future<void> acceptApplicant(String requestId, String applicantId, String role) async {
    try {
      final currentUid = _auth.currentUser!.uid;
      final requestDoc = await _requests.doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Request not found.');
      }

      final requestData = requestDoc.data()!;
      if (requestData[AppFields.creatorId] != currentUid) {
        throw Exception('Only the creator can accept applicants.');
      }

      final applicantDoc = await _applicants.doc(applicantId).get();
      if (!applicantDoc.exists) {
        throw Exception('Applicant not found.');
      }
      final applicantData = applicantDoc.data()!;
      if (applicantData[AppFields.applicantStatus] == CarpoolApplicantStatuses.accepted) {
        return;
      }

      if (role == CarpoolApplicantRoles.driver) {
        final acceptedDriverQuery = await _applicants
            .where(AppFields.requestId, isEqualTo: requestId)
            .where(AppFields.applicantStatus, isEqualTo: CarpoolApplicantStatuses.accepted)
            .where(AppFields.applicantRole, isEqualTo: CarpoolApplicantRoles.driver)
            .limit(1)
            .get();
        if (acceptedDriverQuery.docs.isNotEmpty) {
          throw Exception('Only one driver can be accepted for a request.');
        }
      }

      final requestRef = _requests.doc(requestId);
      final applicantRef = _applicants.doc(applicantId);
      final applicantUserId = applicantData[AppFields.userId] as String;

      final groupRef = _groups.doc(requestId);
      final groupDoc = await groupRef.get();

      await _firestore.runTransaction((transaction) async {
        transaction.update(applicantRef, {AppFields.applicantStatus: CarpoolApplicantStatuses.accepted});

        final currentSeats = (requestDoc.data()?[AppFields.availableSeats] as num?)?.toInt() ?? 0;
        if (role == CarpoolApplicantRoles.passenger) {
          final newSeats = max(0, currentSeats - 1);
          final newStatus = newSeats == 0 ? CarpoolRequestStatuses.confirmed : requestData[AppFields.status] as String;
          transaction.update(requestRef, {
            AppFields.availableSeats: newSeats,
            if (newSeats == 0) AppFields.status: CarpoolRequestStatuses.confirmed,
            if (newSeats != 0) AppFields.status: newStatus,
          });
        }

        if (!groupDoc.exists) {
          transaction.set(groupRef, CarpoolGroupModel(
            id: groupRef.id,
            requestId: requestId,
            adminId: currentUid,
            memberIds: [currentUid, applicantUserId],
            createdAt: DateTime.now(),
          ).toMap());
        } else {
          final existingMembers = (groupDoc.data()?[AppFields.memberIds] as List<dynamic>? ?? const []).map((value) => value.toString()).toList();
          if (!existingMembers.contains(applicantUserId)) {
            existingMembers.add(applicantUserId);
          }
          transaction.update(groupRef, {AppFields.memberIds: existingMembers});
        }
      });

      await _notificationService.sendFCMToUser(
        applicantUserId,
        'Application accepted',
        'Your carpool application was accepted.',
      );
    } catch (error) {
      throw Exception('Failed to accept applicant: $error');
    }
  }

  /// Rejects a pending applicant.
  Future<void> rejectApplicant(String requestId, String applicantId) async {
    try {
      final currentUid = _auth.currentUser!.uid;
      final requestDoc = await _requests.doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Request not found.');
      }
      if ((requestDoc.data()?[AppFields.creatorId] as String?) != currentUid) {
        throw Exception('Only the creator can reject applicants.');
      }

      await _applicants.doc(applicantId).update({AppFields.applicantStatus: CarpoolApplicantStatuses.rejected});
    } catch (error) {
      throw Exception('Failed to reject applicant: $error');
    }
  }

  /// Streams applicants for a given request.
  Stream<List<CarpoolApplicantModel>> getApplicants(String requestId) {
    try {
      return _applicants
          .where(AppFields.requestId, isEqualTo: requestId)
          .orderBy(AppFields.appliedAt, descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => CarpoolApplicantModel.fromMap(doc.data(), doc.id)).toList());
    } catch (error) {
      throw Exception('Failed to load applicants: $error');
    }
  }

  /// Returns open requests within the requested radius in kilometers.
  Future<List<CarpoolRequestModel>> getNearbyRequests(double lat, double lng, double radiusKm) async {
    try {
      final snapshot = await _requests.where(AppFields.status, isEqualTo: CarpoolRequestStatuses.open).get();
      return snapshot.docs.map((doc) => CarpoolRequestModel.fromMap(doc.data(), doc.id)).where((request) {
        final distanceMeters = Geolocator.distanceBetween(lat, lng, request.originLat, request.originLng);
        return distanceMeters <= radiusKm * 1000;
      }).toList();
    } catch (error) {
      throw Exception('Failed to load nearby requests: $error');
    }
  }

  /// Reads the carpool group associated with a request.
  Future<CarpoolGroupModel?> getGroupByRequestId(String requestId) async {
    try {
      final doc = await _groups.doc(requestId).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return CarpoolGroupModel.fromMap(doc.data()!, doc.id);
    } catch (error) {
      throw Exception('Failed to load group: $error');
    }
  }

  /// Creates a report document for a carpool issue.
  Future<void> createReport({
    required String requestId,
    required String reportedBy,
    required String targetUserId,
    required String reason,
    required String description,
  }) async {
    try {
      final group = await getGroupByRequestId(requestId);
      if (group == null || !group.memberIds.contains(targetUserId) || !group.memberIds.contains(reportedBy)) {
        throw Exception('You can only report users in the same carpool group.');
      }

      await _firestore.collection(AppCollections.rideReports).doc().set({
        AppFields.requestId: requestId,
        AppFields.reportedBy: reportedBy,
        AppFields.targetUserId: targetUserId,
        AppFields.reason: reason,
        AppFields.description: description,
        AppFields.status: CarpoolReportStatuses.open,
        AppFields.createdAt: Timestamp.now(),
      });
    } catch (error) {
      throw Exception('Failed to create report: $error');
    }
  }
}