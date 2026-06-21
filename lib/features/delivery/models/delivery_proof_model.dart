import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unipool/core/constants.dart';

class DeliveryProofModel {
  const DeliveryProofModel({
    required this.id,
    required this.driverId,
    required this.stopIndex,
    required this.photoUrls,
    required this.notes,
    required this.status,
    required this.reviewedBy,
    required this.reviewedAt,
    required this.createdAt,
  });

  final String id;
  final String driverId;
  final int? stopIndex;
  final List<String> photoUrls;
  final String notes;
  final String status;
  final String reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  factory DeliveryProofModel.fromMap(Map<String, dynamic> map, String id) {
    return DeliveryProofModel(
      id: id,
      driverId: map[AppFields.driverId] as String? ?? '',
      stopIndex: (map[AppFields.stopIndex] as num?)?.toInt(),
      photoUrls:
          (map[AppFields.photoUrls] as List<dynamic>? ?? const [])
              .map((url) => url.toString())
              .toList(),
      notes: map[AppFields.notes] as String? ?? '',
      status:
          map[AppFields.status] as String? ?? DeliveryProofStatuses.submitted,
      reviewedBy: map[AppFields.reviewedBy] as String? ?? '',
      reviewedAt: (map[AppFields.reviewedAt] as Timestamp?)?.toDate(),
      createdAt:
          (map[AppFields.createdAt] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      AppFields.driverId: driverId,
      if (stopIndex != null) AppFields.stopIndex: stopIndex,
      AppFields.photoUrls: photoUrls,
      AppFields.notes: notes,
      AppFields.status: status,
      AppFields.reviewedBy: reviewedBy,
      if (reviewedAt != null)
        AppFields.reviewedAt: Timestamp.fromDate(reviewedAt!),
      AppFields.createdAt: Timestamp.fromDate(createdAt),
    };
  }

  DeliveryProofModel copyWith({
    String? id,
    String? driverId,
    int? stopIndex,
    List<String>? photoUrls,
    String? notes,
    String? status,
    String? reviewedBy,
    DateTime? reviewedAt,
    DateTime? createdAt,
  }) {
    return DeliveryProofModel(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      stopIndex: stopIndex ?? this.stopIndex,
      photoUrls: photoUrls ?? this.photoUrls,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
