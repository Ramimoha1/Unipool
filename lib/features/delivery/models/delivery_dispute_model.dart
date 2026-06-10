import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unipool/core/constants.dart';

class DeliveryDisputeModel {
  const DeliveryDisputeModel({
    required this.id,
    required this.jobId,
    required this.sellerId,
    required this.driverId,
    required this.reason,
    required this.description,
    required this.evidenceUrls,
    required this.status,
    required this.reviewedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String jobId;
  final String sellerId;
  final String driverId;
  final String reason;
  final String description;
  final List<String> evidenceUrls;
  final String status;
  final String reviewedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory DeliveryDisputeModel.fromMap(Map<String, dynamic> map, String id) {
    return DeliveryDisputeModel(
      id: id,
      jobId: map[AppFields.jobId] as String? ?? '',
      sellerId: map[AppFields.sellerId] as String? ?? '',
      driverId: map[AppFields.driverId] as String? ?? '',
      reason: map[AppFields.reason] as String? ?? '',
      description: map[AppFields.description] as String? ?? '',
      evidenceUrls:
          (map[AppFields.evidenceUrls] as List<dynamic>? ?? const [])
              .map((url) => url.toString())
              .toList(),
      status:
          map[AppFields.status] as String? ?? DeliveryDisputeStatuses.open,
      reviewedBy: map[AppFields.reviewedBy] as String? ?? '',
      createdAt:
          (map[AppFields.createdAt] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (map[AppFields.updatedAt] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      AppFields.jobId: jobId,
      AppFields.sellerId: sellerId,
      AppFields.driverId: driverId,
      AppFields.reason: reason,
      AppFields.description: description,
      AppFields.evidenceUrls: evidenceUrls,
      AppFields.status: status,
      AppFields.reviewedBy: reviewedBy,
      AppFields.createdAt: Timestamp.fromDate(createdAt),
      AppFields.updatedAt: Timestamp.fromDate(updatedAt),
    };
  }

  DeliveryDisputeModel copyWith({
    String? id,
    String? jobId,
    String? sellerId,
    String? driverId,
    String? reason,
    String? description,
    List<String>? evidenceUrls,
    String? status,
    String? reviewedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeliveryDisputeModel(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      sellerId: sellerId ?? this.sellerId,
      driverId: driverId ?? this.driverId,
      reason: reason ?? this.reason,
      description: description ?? this.description,
      evidenceUrls: evidenceUrls ?? this.evidenceUrls,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
