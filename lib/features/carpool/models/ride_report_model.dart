import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unipool/core/constants.dart';

class RideReportModel {
  const RideReportModel({
    required this.id,
    required this.requestId,
    required this.reportedBy,
    required this.targetUserId,
    required this.reason,
    required this.description,
    required this.status,
    required this.createdAt,
    this.attachmentUrls = const [],
    this.chatSnapshot = const [],
  });

  final String id;
  final String requestId;
  final String reportedBy;
  final String targetUserId;
  final String reason;
  final String description;
  final String status;
  final DateTime createdAt;
  final List<String> attachmentUrls;
  final List<Map<String, dynamic>> chatSnapshot;

  factory RideReportModel.fromMap(Map<String, dynamic> map, String id) {
    return RideReportModel(
      id: id,
      requestId: map[AppFields.requestId] as String? ?? '',
      reportedBy: map[AppFields.reportedBy] as String? ?? '',
      targetUserId: map[AppFields.targetUserId] as String? ?? '',
      reason: map[AppFields.reason] as String? ?? CarpoolReportReasons.other,
      description: map[AppFields.description] as String? ?? '',
      status: map[AppFields.status] as String? ?? CarpoolReportStatuses.open,
      createdAt: (map[AppFields.createdAt] as Timestamp?)?.toDate() ?? DateTime.now(),
      attachmentUrls: (map[AppFields.attachmentUrls] as List<dynamic>?)?.cast<String>() ?? [],
      chatSnapshot: (map[AppFields.chatSnapshot] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      AppFields.requestId: requestId,
      AppFields.reportedBy: reportedBy,
      AppFields.targetUserId: targetUserId,
      AppFields.reason: reason,
      AppFields.description: description,
      AppFields.status: status,
      AppFields.createdAt: Timestamp.fromDate(createdAt),
      AppFields.attachmentUrls: attachmentUrls,
      AppFields.chatSnapshot: chatSnapshot,
    };
  }

  RideReportModel copyWith({
    String? id,
    String? requestId,
    String? reportedBy,
    String? targetUserId,
    String? reason,
    String? description,
    String? status,
    DateTime? createdAt,
    List<String>? attachmentUrls,
    List<Map<String, dynamic>>? chatSnapshot,
  }) {
    return RideReportModel(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      reportedBy: reportedBy ?? this.reportedBy,
      targetUserId: targetUserId ?? this.targetUserId,
      reason: reason ?? this.reason,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      chatSnapshot: chatSnapshot ?? this.chatSnapshot,
    );
  }
}