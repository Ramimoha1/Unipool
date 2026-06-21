import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unipool/core/constants.dart';

class RidePaymentModel {
  const RidePaymentModel({
    required this.id,
    required this.requestId,
    required this.bookedByUserId,
    required this.qrCodeUrl,
    this.bankName = '',
    this.accountNumber = '',
    this.accountName = '',
    required this.totalAmount,
    required this.passengerDues,
    required this.status,
    required this.confirmedBy,
    required this.createdAt,
  });

  final String id;
  final String requestId;
  final String bookedByUserId;
  final String qrCodeUrl;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final double totalAmount;
  final Map<String, double> passengerDues;
  final String status;
  final List<String> confirmedBy;
  final DateTime createdAt;

  factory RidePaymentModel.fromMap(Map<String, dynamic> map, String id) {
    return RidePaymentModel(
      id: id,
      requestId: map[AppFields.requestId] as String? ?? '',
      bookedByUserId: map[AppFields.bookedByUserId] as String? ?? '',
      qrCodeUrl: map[AppFields.qrCodeUrl] as String? ?? '',
      bankName: map['bankName'] as String? ?? '',
      accountNumber: map['accountNumber'] as String? ?? '',
      accountName: map['accountName'] as String? ?? '',
      totalAmount: (map[AppFields.totalAmount] as num?)?.toDouble() ?? 0,
      passengerDues: (map['passengerDues'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble())),
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
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountName': accountName,
      AppFields.totalAmount: totalAmount,
      'passengerDues': passengerDues,
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
    String? bankName,
    String? accountNumber,
    String? accountName,
    double? totalAmount,
    Map<String, double>? passengerDues,
    String? status,
    List<String>? confirmedBy,
    DateTime? createdAt,
  }) {
    return RidePaymentModel(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      bookedByUserId: bookedByUserId ?? this.bookedByUserId,
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountName: accountName ?? this.accountName,
      totalAmount: totalAmount ?? this.totalAmount,
      passengerDues: passengerDues ?? this.passengerDues,
      status: status ?? this.status,
      confirmedBy: confirmedBy ?? this.confirmedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}