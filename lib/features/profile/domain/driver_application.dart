import 'package:cloud_firestore/cloud_firestore.dart';

enum DriverApplicationStatus { pending, approved, rejected }

/// Vehicle information submitted with a driver application.
class VehicleInfo {
  final String vehicleType; // 'car' or 'motorcycle'
  final String brand; // e.g. 'Toyota', 'Honda'
  final String model; // e.g. 'Vios', 'City'
  final int year; // e.g. 2021
  final String color; // e.g. 'White'
  final String plateNumber; // e.g. 'ABC 1234'
  final String? vehiclePhotoUrl; // photo showing plate number

  const VehicleInfo({
    required this.vehicleType,
    required this.brand,
    required this.model,
    required this.year,
    required this.color,
    required this.plateNumber,
    this.vehiclePhotoUrl,
  });

  factory VehicleInfo.fromMap(Map<String, dynamic> map) {
    return VehicleInfo(
      vehicleType: map['vehicleType'] as String? ?? 'car',
      brand: map['brand'] as String? ?? '',
      model: map['model'] as String? ?? '',
      year: map['year'] as int? ?? 0,
      color: map['color'] as String? ?? '',
      plateNumber: map['plateNumber'] as String? ?? '',
      vehiclePhotoUrl: map['vehiclePhotoUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vehicleType': vehicleType,
      'brand': brand,
      'model': model,
      'year': year,
      'color': color,
      'plateNumber': plateNumber,
      if (vehiclePhotoUrl != null) 'vehiclePhotoUrl': vehiclePhotoUrl,
    };
  }
}

class DriverApplication {
  final String? id;
  final String userId;
  final DriverApplicationStatus status;
  final String? studentCardUrl;
  final String? driverLicenseUrl;
  final VehicleInfo? vehicleInfo;
  final String? notes;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  const DriverApplication({
    this.id,
    required this.userId,
    required this.status,
    this.studentCardUrl,
    this.driverLicenseUrl,
    this.vehicleInfo,
    this.notes,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
  });

  factory DriverApplication.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DriverApplication(
      id: doc.id,
      userId: data['userId'] as String,
      status: _statusFromString(data['status'] as String? ?? 'pending'),
      studentCardUrl: data['studentCardUrl'] as String?,
      driverLicenseUrl: data['driverLicenseUrl'] as String?,
      vehicleInfo: data['vehicleInfo'] != null
          ? VehicleInfo.fromMap(data['vehicleInfo'] as Map<String, dynamic>)
          : null,
      notes: data['notes'] as String?,
      reviewedBy: data['reviewedBy'] as String?,
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'status': status.name,
      'studentCardUrl': studentCardUrl,
      'driverLicenseUrl': driverLicenseUrl,
      'vehicleInfo': vehicleInfo?.toMap(),
      'notes': notes,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static DriverApplicationStatus _statusFromString(String value) {
    return DriverApplicationStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DriverApplicationStatus.pending,
    );
  }
}
