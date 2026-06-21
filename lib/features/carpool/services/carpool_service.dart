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
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _notificationService = notificationService ?? NotificationService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final NotificationService _notificationService;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection(AppCollections.carpoolRequests);
  CollectionReference<Map<String, dynamic>> get _applicants =>
      _firestore.collection(AppCollections.carpoolApplicants);
  CollectionReference<Map<String, dynamic>> get _groups =>
      _firestore.collection(AppCollections.carpoolGroups);
  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(AppCollections.users);

  Future<void> _checkBanStatus(String userId) async {
    final doc = await _users.doc(userId).get();
    final data = doc.data();
    if (data == null) return;

    final status = data[AppFields.userBannedStatus] as String?;
    if (status != null && status != 'none') {
      final reason = data[AppFields.userBannedReason] as String? ?? 'No reason provided';
      throw Exception('BANNED: You are currently banned ($status). Reason: $reason.');
    }
  }

  /// Creates a new carpool request and seeds its group document.
  Future<String> createRequest(CarpoolRequestModel request, {bool isCreatorDriver = false}) async {
    try {
      await _checkBanStatus(request.creatorId);
      // Prevent creating a new request if the user already has an active carpool
      final active = await getActiveCarpoolsForUser(request.creatorId);
      if (active.isNotEmpty) {
        throw Exception(
          'You are already in an active carpool. Complete or cancel it before creating another.',
        );
      }
      final requestRef = request.id.isEmpty
          ? _requests.doc()
          : _requests.doc(request.id);
      final groupRef = _groups.doc(requestRef.id);
      final storedRequest = request.copyWith(
        id: requestRef.id,
        createdAt: request.createdAt,
      );

      await _firestore.runTransaction((transaction) async {
        transaction.set(requestRef, storedRequest.toMap());
        transaction.set(
          groupRef,
          CarpoolGroupModel(
            driverId: isCreatorDriver ? request.creatorId : '',
            id: groupRef.id,
            requestId: requestRef.id,
            adminId: request.creatorId,
            memberIds: [request.creatorId],
            createdAt: DateTime.now(),
          ).toMap(),
        );
      });
      return requestRef.id;
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
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => CarpoolRequestModel.fromMap(doc.data(), doc.id))
                .toList(),
          );
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
      return snapshot.docs
          .map((doc) => CarpoolRequestModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (error) {
      throw Exception('Failed to load my requests: $error');
    }
  }

  /// Loads active carpools where the user is a group member (creator, passenger, or driver).
  Future<List<CarpoolRequestModel>> getActiveCarpoolsForUser(
    String userId,
  ) async {
    try {
      final groupSnapshot = await _groups
          .where(AppFields.memberIds, arrayContains: userId)
          .get();
      if (groupSnapshot.docs.isEmpty) {
        return const [];
      }

      final requestIds = groupSnapshot.docs
          .map((doc) => doc.id)
          .toSet()
          .toList();
      final requests = <CarpoolRequestModel>[];

      for (final requestId in requestIds) {
        final requestDoc = await _requests.doc(requestId).get();
        final data = requestDoc.data();
        if (!requestDoc.exists || data == null) {
          continue;
        }

        final request = CarpoolRequestModel.fromMap(data, requestDoc.id);
        if (_isActiveStatus(request.status)) {
          requests.add(request);
        }
      }

      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    } catch (error) {
      throw Exception('Failed to load active carpools: $error');
    }
  }

  bool _isActiveStatus(String status) {
    return status == CarpoolRequestStatuses.open ||
        status == CarpoolRequestStatuses.confirmed ||
        status == CarpoolRequestStatuses.inProgress;
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
      final isCreator = (requestDoc.data()?[AppFields.creatorId] as String?) == currentUid;
      final groupDoc = await _groups.doc(requestId).get();
      final isDriver = groupDoc.exists && (groupDoc.data()?[AppFields.driverId] as String?) == currentUid;

      if (!isCreator && !isDriver) {
        throw Exception('Only the creator or assigned driver can update the request status.');
      }
      await _requests.doc(requestId).update({AppFields.status: status});
    } catch (error) {
      throw Exception('Failed to update request: $error');
    }
  }

  /// Updates settings of a request.
  Future<void> updateRequestSettings(String requestId, Map<String, dynamic> updates) async {
    try {
      final currentUid = _auth.currentUser!.uid;
      final requestDoc = await _requests.doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Request not found.');
      }
      if ((requestDoc.data()?[AppFields.creatorId] as String?) != currentUid) {
        throw Exception('Only the creator can update the request settings.');
      }

      await _requests.doc(requestId).update(updates);
    } catch (error) {
      throw Exception('Failed to update request settings: $error');
    }
  }

  /// Transfers creator ownership of a request to a new member.
  Future<void> transferCreator(String requestId, String newCreatorId) async {
    try {
      final currentUid = _auth.currentUser!.uid;
      final requestDoc = await _requests.doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Request not found.');
      }
      if ((requestDoc.data()?[AppFields.creatorId] as String?) != currentUid) {
        throw Exception('Only the creator can transfer ownership.');
      }

      await _firestore.runTransaction((transaction) async {
        final groupRef = _groups.doc(requestId);
        final groupDoc = await transaction.get(groupRef);
        if (!groupDoc.exists) {
          throw Exception('Group not found.');
        }

        final groupData = groupDoc.data()!;
        final memberIds = List<String>.from(groupData[AppFields.memberIds] ?? []);
        if (!memberIds.contains(newCreatorId)) {
          throw Exception('New creator must be a current member of the group.');
        }

        transaction.update(_requests.doc(requestId), {
          AppFields.creatorId: newCreatorId,
        });
        transaction.update(groupRef, {
          AppFields.adminId: newCreatorId,
        });
      });
    } catch (error) {
      throw Exception('Failed to transfer creator: $error');
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
  Future<void> applyToRequest(
    String requestId,
    String userId,
    String role,
  ) async {
    try {
      await _checkBanStatus(userId);
      // Disallow applying to other requests when user already has an active carpool
      final active = await getActiveCarpoolsForUser(userId);
      if (active.isNotEmpty) {
        // if the active carpool is not this request, block
        final isAlreadyInThis = active.any((r) => r.id == requestId);
        if (!isAlreadyInThis) {
          throw Exception(
            'You are already in an active carpool. Leave it before applying to another.',
          );
        }
      }
      final requestDoc = await _requests.doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Request not found.');
      }

      final requestData = requestDoc.data()!;
      final joinMode =
          (requestData[AppFields.joinMode] as String?) ??
          CarpoolJoinModes.approval;
      if (requestData[AppFields.rideType] == CarpoolRideTypes.grab &&
          role == CarpoolApplicantRoles.driver) {
        throw Exception('Driver applications are not allowed for grab rides.');
      }

      final groupDoc = await _groups.doc(requestId).get();
      if (groupDoc.exists) {
        final group = CarpoolGroupModel.fromMap(groupDoc.data()!, groupDoc.id);
        if (group.memberIds.contains(userId)) {
          throw Exception('You are already in this carpool.');
        }
      }

      final existingApplication = await _applicants
          .where(AppFields.requestId, isEqualTo: requestId)
          .where(AppFields.userId, isEqualTo: userId)
          .limit(1)
          .get();
      if (existingApplication.docs.isNotEmpty) {
        throw Exception('You have already applied to this request.');
      }

      if (role == CarpoolApplicantRoles.driver &&
          requestData[AppFields.allowUnverifiedDriver] == false) {
        final userDoc = await _firestore
            .collection(AppCollections.users)
            .doc(userId)
            .get();
        final userData = userDoc.data();
        final userRole =
            (userData?[AppFields.userRole] as String?) ??
            (userData?[AppFields.userType] as String?);
        if (userRole != 'verified_driver') {
          throw Exception('Only verified drivers can apply for this request.');
        }
      }

      if (role == CarpoolApplicantRoles.passenger &&
          joinMode == CarpoolJoinModes.open) {
        final requestRef = _requests.doc(requestId);
        final groupRef = _groups.doc(requestId);
        final applicantRef = _applicants.doc();

        await _firestore.runTransaction((transaction) async {
          final latestRequest = await transaction.get(requestRef);
          final latestGroup = await transaction.get(groupRef);
          if (!latestRequest.exists || latestRequest.data() == null) {
            throw Exception('Request not found.');
          }

          final latestData = latestRequest.data()!;
          final availableSeats =
              (latestData[AppFields.availableSeats] as num?)?.toInt() ?? 0;
          if (availableSeats <= 0) {
            throw Exception('No seats available.');
          }

          final newSeats = max(0, availableSeats - 1);
          transaction.update(requestRef, {
            AppFields.availableSeats: newSeats,
            if (newSeats == 0)
              AppFields.status: CarpoolRequestStatuses.confirmed,
          });

          if (!latestGroup.exists || latestGroup.data() == null) {
            transaction.set(
              groupRef,
              CarpoolGroupModel(
                id: requestId,
                requestId: requestId,
                adminId: latestData[AppFields.creatorId] as String? ?? '',
                driverId: role == CarpoolApplicantRoles.driver ? userId : '',
                memberIds: [
                  latestData[AppFields.creatorId] as String? ?? '',
                  userId,
                ],
                createdAt: DateTime.now(),
              ).toMap(),
            );
          } else {
            final memberIds =
                (latestGroup.data()?[AppFields.memberIds] as List<dynamic>? ??
                        const [])
                    .map((value) => value.toString())
                    .toList();
            if (!memberIds.contains(userId)) {
              memberIds.add(userId);
              transaction.update(groupRef, {AppFields.memberIds: memberIds});
            }
            if (role == CarpoolApplicantRoles.driver) {
              transaction.update(groupRef, {AppFields.driverId: userId});
            }
          }

          transaction.set(
            applicantRef,
            CarpoolApplicantModel(
              id: applicantRef.id,
              requestId: requestId,
              userId: userId,
              applicantRole: role,
              status: CarpoolApplicantStatuses.accepted,
              appliedAt: DateTime.now(),
            ).toMap(),
          );
        });
        return;
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

  /// Withdraws a pending application.
  Future<void> withdrawApplication(String applicantId) async {
    try {
      final currentUid = _auth.currentUser!.uid;
      final applicantDoc = await _applicants.doc(applicantId).get();
      if (!applicantDoc.exists) {
        throw Exception('Application not found.');
      }
      if (applicantDoc.data()![AppFields.userId] != currentUid) {
        throw Exception('You can only withdraw your own application.');
      }
      await _applicants.doc(applicantId).delete();
    } catch (error) {
      throw Exception('Failed to withdraw application: $error');
    }
  }

  /// Streams the current user's application for a specific request.
  Stream<CarpoolApplicantModel?> getUserApplication(
    String requestId,
    String userId,
  ) {
    return _applicants
        .where(AppFields.requestId, isEqualTo: requestId)
        .where(AppFields.userId, isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return null;
          }
          final doc = snapshot.docs.first;
          return CarpoolApplicantModel.fromMap(doc.data(), doc.id);
        });
  }

  /// Accepts an applicant and updates request seats, group membership, and notifications.
  Future<void> acceptApplicant(
    String requestId,
    String applicantId,
    String role,
  ) async {
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
      if (applicantData[AppFields.applicantStatus] ==
          CarpoolApplicantStatuses.accepted) {
        return;
      }

      if (role == CarpoolApplicantRoles.driver) {
        final acceptedDriverQuery = await _applicants
            .where(AppFields.requestId, isEqualTo: requestId)
            .where(
              AppFields.applicantStatus,
              isEqualTo: CarpoolApplicantStatuses.accepted,
            )
            .where(
              AppFields.applicantRole,
              isEqualTo: CarpoolApplicantRoles.driver,
            )
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
        transaction.update(applicantRef, {
          AppFields.applicantStatus: CarpoolApplicantStatuses.accepted,
        });

        final currentSeats =
            (requestDoc.data()?[AppFields.availableSeats] as num?)?.toInt() ??
            0;
        if (role == CarpoolApplicantRoles.passenger) {
          final newSeats = max(0, currentSeats - 1);
          final newStatus = newSeats == 0
              ? CarpoolRequestStatuses.confirmed
              : requestData[AppFields.status] as String;
          transaction.update(requestRef, {
            AppFields.availableSeats: newSeats,
            if (newSeats == 0)
              AppFields.status: CarpoolRequestStatuses.confirmed,
            if (newSeats != 0) AppFields.status: newStatus,
          });
        }

        if (!groupDoc.exists) {
          transaction.set(
            groupRef,
            CarpoolGroupModel(
              id: groupRef.id,
              requestId: requestId,
              adminId: currentUid,
              driverId: role == CarpoolApplicantRoles.driver ? applicantUserId : '',
              memberIds: [currentUid, applicantUserId],
              createdAt: DateTime.now(),
            ).toMap(),
          );
        } else {
          final existingMembers =
              (groupDoc.data()?[AppFields.memberIds] as List<dynamic>? ??
                      const [])
                  .map((value) => value.toString())
                  .toList();
          if (!existingMembers.contains(applicantUserId)) {
            existingMembers.add(applicantUserId);
          }
          final updates = <String, dynamic>{
            AppFields.memberIds: existingMembers,
          };
          if (role == CarpoolApplicantRoles.driver) {
            updates[AppFields.driverId] = applicantUserId;
          }
          transaction.update(groupRef, updates);
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

      await _applicants.doc(applicantId).update({
        AppFields.applicantStatus: CarpoolApplicantStatuses.rejected,
      });
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
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => CarpoolApplicantModel.fromMap(doc.data(), doc.id))
                .toList(),
          );
    } catch (error) {
      throw Exception('Failed to load applicants: $error');
    }
  }

  /// Returns open requests within the requested radius in kilometers.
  Future<List<CarpoolRequestModel>> getNearbyRequests(
    double lat,
    double lng,
    double radiusKm,
  ) async {
    try {
      final snapshot = await _requests
          .where(AppFields.status, isEqualTo: CarpoolRequestStatuses.open)
          .get();
      return snapshot.docs
          .map((doc) => CarpoolRequestModel.fromMap(doc.data(), doc.id))
          .where((request) {
            final distanceMeters = Geolocator.distanceBetween(
              lat,
              lng,
              request.originLat,
              request.originLng,
            );
            return distanceMeters <= radiusKm * 1000;
          })
          .toList();
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

  /// Removes a user from the carpool group. If the user is the creator, they must cancel the request instead.
  Future<void> leaveGroup(String requestId, String userId) async {
    try {
      final groupRef = _groups.doc(requestId);
      final requestRef = _requests.doc(requestId);
      final groupDoc = await groupRef.get();
      if (!groupDoc.exists) {
        throw Exception('Group not found.');
      }

      final group = CarpoolGroupModel.fromMap(groupDoc.data()!, groupDoc.id);
      if (group.adminId == userId) {
        throw Exception(
          'Creator cannot leave the group. Cancel the request instead.',
        );
      }

      final application = await _applicants
          .where(AppFields.requestId, isEqualTo: requestId)
          .where(AppFields.userId, isEqualTo: userId)
          .where(
            AppFields.applicantStatus,
            isEqualTo: CarpoolApplicantStatuses.accepted,
          )
          .limit(1)
          .get();

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot<Map<String, dynamic>>? requestDoc;
        final acceptedRole = application.docs.isNotEmpty
            ? application.docs.first.data()[AppFields.applicantRole] as String?
            : null;

        if (acceptedRole == CarpoolApplicantRoles.passenger) {
          requestDoc = await transaction.get(requestRef);
        }

        final updatedMembers = List<String>.from(group.memberIds)
          ..remove(userId);
        transaction.update(groupRef, {AppFields.memberIds: updatedMembers});

        if (application.docs.isNotEmpty) {
          final acceptedDoc = application.docs.first;
          if (acceptedRole == CarpoolApplicantRoles.passenger && requestDoc != null) {
            final requestData = requestDoc.data() ?? <String, dynamic>{};
            final availableSeats =
                (requestData[AppFields.availableSeats] as num?)?.toInt() ?? 0;
            final totalSeats =
                (requestData[AppFields.totalSeats] as num?)?.toInt() ??
                availableSeats;
            transaction.update(requestRef, {
              AppFields.availableSeats: min(totalSeats, availableSeats + 1),
              if ((requestData[AppFields.status] as String?) ==
                  CarpoolRequestStatuses.confirmed)
                AppFields.status: CarpoolRequestStatuses.open,
            });
          }
          if (acceptedRole == CarpoolApplicantRoles.driver) {
            transaction.update(groupRef, {AppFields.driverId: ''});
          }
          transaction.delete(_applicants.doc(acceptedDoc.id));
        }
      });
    } catch (error) {
      throw Exception('Failed to leave group: $error');
    }
  }

  /// Allows the creator/admin to remove a member from their carpool group.
  Future<void> kickMember(String requestId, String targetUserId) async {
    try {
      final currentUid = _auth.currentUser!.uid;
      final groupRef = _groups.doc(requestId);
      final requestRef = _requests.doc(requestId);
      final groupDoc = await groupRef.get();
      if (!groupDoc.exists || groupDoc.data() == null) {
        throw Exception('Group not found.');
      }

      final group = CarpoolGroupModel.fromMap(groupDoc.data()!, groupDoc.id);
      if (group.adminId != currentUid) {
        throw Exception('Only the creator can remove members.');
      }
      if (targetUserId == currentUid) {
        throw Exception('Creator cannot remove themselves.');
      }
      if (!group.memberIds.contains(targetUserId)) {
        return;
      }

      final application = await _applicants
          .where(AppFields.requestId, isEqualTo: requestId)
          .where(AppFields.userId, isEqualTo: targetUserId)
          .where(
            AppFields.applicantStatus,
            isEqualTo: CarpoolApplicantStatuses.accepted,
          )
          .limit(1)
          .get();

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot<Map<String, dynamic>>? requestDoc;
        final acceptedRole = application.docs.isNotEmpty
            ? application.docs.first.data()[AppFields.applicantRole] as String?
            : null;

        if (acceptedRole == CarpoolApplicantRoles.passenger) {
          requestDoc = await transaction.get(requestRef);
        }

        final updatedMembers = List<String>.from(group.memberIds)
          ..remove(targetUserId);
        transaction.update(groupRef, {AppFields.memberIds: updatedMembers});

        if (application.docs.isNotEmpty) {
          final acceptedDoc = application.docs.first;
          if (acceptedRole == CarpoolApplicantRoles.passenger && requestDoc != null) {
            final requestData = requestDoc.data() ?? <String, dynamic>{};
            final availableSeats =
                (requestData[AppFields.availableSeats] as num?)?.toInt() ?? 0;
            final totalSeats =
                (requestData[AppFields.totalSeats] as num?)?.toInt() ??
                availableSeats;
            transaction.update(requestRef, {
              AppFields.availableSeats: min(totalSeats, availableSeats + 1),
              if ((requestData[AppFields.status] as String?) ==
                  CarpoolRequestStatuses.confirmed)
                AppFields.status: CarpoolRequestStatuses.open,
            });
          }
          if (acceptedRole == CarpoolApplicantRoles.driver) {
            transaction.update(groupRef, {AppFields.driverId: ''});
          }
          transaction.delete(_applicants.doc(acceptedDoc.id));
        }
      });

      await _notificationService.sendFCMToUser(
        targetUserId,
        'Removed from carpool',
        'The creator removed you from this ride.',
      );
    } catch (error) {
      throw Exception('Failed to remove member: $error');
    }
  }

  /// Creates a report document for a carpool issue.
  Future<void> createReport({
    required String requestId,
    required String reportedBy,
    required String targetUserId,
    required String reason,
    required String description,
    required List<String> attachmentUrls,
    required List<Map<String, dynamic>> chatSnapshot,
  }) async {
    try {
      final group = await getGroupByRequestId(requestId);
      if (group == null ||
          !group.memberIds.contains(targetUserId) ||
          !group.memberIds.contains(reportedBy)) {
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
        AppFields.attachmentUrls: attachmentUrls,
        AppFields.chatSnapshot: chatSnapshot,
      });
    } catch (error) {
      throw Exception('Failed to create report: $error');
    }
  }
}
