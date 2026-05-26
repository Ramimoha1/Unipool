import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unipool/core/constants.dart';

class RidePaymentModel {
  const RidePaymentModel({
    required this.id,
    required this.requestId,
    required this.bookedByUserId,
    required this.qrCodeUrl,
    required this.totalAmount,
    required this.splitAmount,
    required this.status,
    required this.confirmedBy,
    required this.createdAt,
  });

  final String id;
  final String requestId;
  final String bookedByUserId;
  final String qrCodeUrl;
  final double totalAmount;
  final double splitAmount;
  final String status;
  final List<String> confirmedBy;
  final DateTime createdAt;

  factory RidePaymentModel.fromMap(Map<String, dynamic> map, String id) {
    return RidePaymentModel(
      id: id,
      requestId: map[AppFields.requestId] as String? ?? '',
      bookedByUserId: map[AppFields.bookedByUserId] as String? ?? '',
      qrCodeUrl: map[AppFields.qrCodeUrl] as String? ?? '',
      totalAmount: (map[AppFields.totalAmount] as num?)?.toDouble() ?? 0,
      splitAmount: (map[AppFields.splitAmount] as num?)?.toDouble() ?? 0,
      status: map[AppFields.paymentStatus] as String? ?? CarpoolPaymentStatuses.pending,
      confirmedBy: (map[AppFields.confirmedBy] as List<dynamic>? ?? const []).map((value) => value.toString()).toList(),
      createdAt: (map[AppFields.createdAt] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      AppFields.requestId: requestId,
      AppFields.bookedByUserId: bookedByUserId,
      AppFields.qrCodeUrl: qrCodeUrl,
      AppFields.totalAmount: totalAmount,
      AppFields.splitAmount: splitAmount,
      AppFields.paymentStatus: status,
      AppFields.confirmedBy: confirmedBy,
      AppFields.createdAt: Timestamp.fromDate(createdAt),
    };
  }

  RidePaymentModel copyWith({
    String? id,
    String? requestId,
    String? bookedByUserId,
    String? qrCodeUrl,
    double? totalAmount,
    double? splitAmount,
    String? status,
    List<String>? confirmedBy,
    DateTime? createdAt,
  }) {
    return RidePaymentModel(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      bookedByUserId: bookedByUserId ?? this.bookedByUserId,
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
      totalAmount: totalAmount ?? this.totalAmount,
      splitAmount: splitAmount ?? this.splitAmount,
      status: status ?? this.status,
      confirmedBy: confirmedBy ?? this.confirmedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}