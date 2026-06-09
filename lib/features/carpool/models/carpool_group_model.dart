import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unipool/core/constants.dart';

class CarpoolGroupModel {
  const CarpoolGroupModel({
    required this.id,
    required this.requestId,
    required this.adminId,
    required this.driverId,
    required this.memberIds,
    required this.createdAt,
  });

  final String id;
  final String requestId;
  final String adminId;
  final String driverId;
  final List<String> memberIds;
  final DateTime createdAt;

  factory CarpoolGroupModel.fromMap(Map<String, dynamic> map, String id) {
    return CarpoolGroupModel(
      id: id,
      requestId: map[AppFields.requestId] as String? ?? '',
      adminId: map[AppFields.adminId] as String? ?? '',
      driverId: map[AppFields.driverId] as String? ?? '',
      memberIds: (map[AppFields.memberIds] as List<dynamic>? ?? const []).map((value) => value.toString()).toList(),
      createdAt: (map[AppFields.createdAt] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      AppFields.requestId: requestId,
      AppFields.adminId: adminId,
      AppFields.driverId: driverId,
      AppFields.memberIds: memberIds,
      AppFields.createdAt: Timestamp.fromDate(createdAt),
    };
  }

  CarpoolGroupModel copyWith({
    String? id,
    String? requestId,
    String? adminId,
    String? driverId,
    List<String>? memberIds,
    DateTime? createdAt,
  }) {
    return CarpoolGroupModel(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      adminId: adminId ?? this.adminId,
      driverId: driverId ?? this.driverId,
      memberIds: memberIds ?? this.memberIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}