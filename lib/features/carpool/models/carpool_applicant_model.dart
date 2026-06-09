import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unipool/core/constants.dart';

class CarpoolApplicantModel {
  const CarpoolApplicantModel({
    required this.id,
    required this.requestId,
    required this.userId,
    required this.applicantRole,
    required this.status,
    required this.appliedAt,
  });

  final String id;
  final String requestId;
  final String userId;
  final String applicantRole;
  final String status;
  final DateTime appliedAt;

  factory CarpoolApplicantModel.fromMap(Map<String, dynamic> map, String id) {
    return CarpoolApplicantModel(
      id: id,
      requestId: map[AppFields.requestId] as String? ?? '',
      userId: map[AppFields.userId] as String? ?? '',
      applicantRole: map[AppFields.applicantRole] as String? ?? CarpoolApplicantRoles.passenger,
      status: map[AppFields.applicantStatus] as String? ?? CarpoolApplicantStatuses.pending,
      appliedAt: (map[AppFields.appliedAt] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      AppFields.requestId: requestId,
      AppFields.userId: userId,
      AppFields.applicantRole: applicantRole,
      AppFields.applicantStatus: status,
      AppFields.appliedAt: Timestamp.fromDate(appliedAt),
    };
  }

  CarpoolApplicantModel copyWith({
    String? id,
    String? requestId,
    String? userId,
    String? applicantRole,
    String? status,
    DateTime? appliedAt,
  }) {
    return CarpoolApplicantModel(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      userId: userId ?? this.userId,
      applicantRole: applicantRole ?? this.applicantRole,
      status: status ?? this.status,
      appliedAt: appliedAt ?? this.appliedAt,
    );
  }
}