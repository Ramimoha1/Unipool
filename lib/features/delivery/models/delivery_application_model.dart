import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unipool/core/constants.dart';

class DeliveryApplicationModel {
  const DeliveryApplicationModel({
    required this.id,
    required this.jobId,
    required this.driverId,
    required this.status,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String jobId;
  final String driverId;
  final String status;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory DeliveryApplicationModel.fromMap(
    Map<String, dynamic> map,
    String id,
  ) {
    return DeliveryApplicationModel(
      id: id,
      jobId: map[AppFields.jobId] as String? ?? '',
      driverId: map[AppFields.driverId] as String? ?? '',
      status: map[AppFields.status] as String? ??
          DeliveryApplicationStatuses.pending,
      notes: map[AppFields.notes] as String? ?? '',
      createdAt:
          (map[AppFields.createdAt] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (map[AppFields.updatedAt] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      AppFields.jobId: jobId,
      AppFields.driverId: driverId,
      AppFields.status: status,
      AppFields.notes: notes,
      AppFields.createdAt: Timestamp.fromDate(createdAt),
      AppFields.updatedAt: Timestamp.fromDate(updatedAt),
    };
  }

  DeliveryApplicationModel copyWith({
    String? id,
    String? jobId,
    String? driverId,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeliveryApplicationModel(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      driverId: driverId ?? this.driverId,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
