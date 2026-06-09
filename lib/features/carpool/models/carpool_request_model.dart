import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unipool/core/constants.dart';

class CarpoolRequestModel {
  const CarpoolRequestModel({
    required this.id,
    required this.creatorId,
    required this.originLabel,
    required this.originLat,
    required this.originLng,
    required this.destinationLabel,
    required this.destinationLat,
    required this.destinationLng,
    required this.scheduledAt,
    required this.totalSeats,
    required this.availableSeats,
    required this.rideType,
    required this.allowUnverifiedDriver,
    required this.joinMode,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String creatorId;
  final String originLabel;
  final double originLat;
  final double originLng;
  final String destinationLabel;
  final double destinationLat;
  final double destinationLng;
  final DateTime scheduledAt;
  final int totalSeats;
  final int availableSeats;
  final String rideType;
  final bool allowUnverifiedDriver;
  final String joinMode;
  final String status;
  final DateTime createdAt;

  factory CarpoolRequestModel.fromMap(Map<String, dynamic> map, String id) {
    return CarpoolRequestModel(
      id: id,
      creatorId: map[AppFields.creatorId] as String? ?? '',
      originLabel: map[AppFields.originLabel] as String? ?? '',
      originLat: (map[AppFields.originLat] as num?)?.toDouble() ?? 0,
      originLng: (map[AppFields.originLng] as num?)?.toDouble() ?? 0,
      destinationLabel: map[AppFields.destinationLabel] as String? ?? '',
      destinationLat: (map[AppFields.destinationLat] as num?)?.toDouble() ?? 0,
      destinationLng: (map[AppFields.destinationLng] as num?)?.toDouble() ?? 0,
      scheduledAt: (map[AppFields.scheduledAt] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalSeats: (map[AppFields.totalSeats] as num?)?.toInt() ?? 0,
      availableSeats: (map[AppFields.availableSeats] as num?)?.toInt() ?? 0,
      rideType: map[AppFields.rideType] as String? ?? CarpoolRideTypes.studentDriver,
      allowUnverifiedDriver: map[AppFields.allowUnverifiedDriver] as bool? ?? false,
      joinMode: map[AppFields.joinMode] as String? ?? CarpoolJoinModes.approval,
      status: map[AppFields.status] as String? ?? CarpoolRequestStatuses.open,
      createdAt: (map[AppFields.createdAt] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      AppFields.creatorId: creatorId,
      AppFields.originLabel: originLabel,
      AppFields.originLat: originLat,
      AppFields.originLng: originLng,
      AppFields.destinationLabel: destinationLabel,
      AppFields.destinationLat: destinationLat,
      AppFields.destinationLng: destinationLng,
      AppFields.scheduledAt: Timestamp.fromDate(scheduledAt),
      AppFields.totalSeats: totalSeats,
      AppFields.availableSeats: availableSeats,
      AppFields.rideType: rideType,
      AppFields.allowUnverifiedDriver: allowUnverifiedDriver,
      AppFields.joinMode: joinMode,
      AppFields.status: status,
      AppFields.createdAt: Timestamp.fromDate(createdAt),
    };
  }

  CarpoolRequestModel copyWith({
    String? id,
    String? creatorId,
    String? originLabel,
    double? originLat,
    double? originLng,
    String? destinationLabel,
    double? destinationLat,
    double? destinationLng,
    DateTime? scheduledAt,
    int? totalSeats,
    int? availableSeats,
    String? rideType,
    bool? allowUnverifiedDriver,
    String? joinMode,
    String? status,
    DateTime? createdAt,
  }) {
    return CarpoolRequestModel(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      originLabel: originLabel ?? this.originLabel,
      originLat: originLat ?? this.originLat,
      originLng: originLng ?? this.originLng,
      destinationLabel: destinationLabel ?? this.destinationLabel,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      totalSeats: totalSeats ?? this.totalSeats,
      availableSeats: availableSeats ?? this.availableSeats,
      rideType: rideType ?? this.rideType,
      allowUnverifiedDriver: allowUnverifiedDriver ?? this.allowUnverifiedDriver,
      joinMode: joinMode ?? this.joinMode,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}