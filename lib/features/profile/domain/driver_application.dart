import 'package:cloud_firestore/cloud_firestore.dart';

enum DriverApplicationStatus { pending, approved, rejected }

class DriverApplication {
  final String? id;
  final String userId;
  final DriverApplicationStatus status;
  final String? studentCardUrl;
  final String? driverLicenseUrl;
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
