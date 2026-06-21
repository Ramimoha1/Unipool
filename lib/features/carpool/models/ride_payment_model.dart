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
    this.bankName = '',
    this.accountHolderName = '',
    this.accountNumber = '',
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

  // Populated server-side by the copyPayeeBankDetails Cloud Function as
  // a snapshot taken at trigger time — see functions/src/index.ts.
  // May be empty if the payee never set up bank details (QR-only payers
  // will just have qrCodeUrl populated and these left blank).
  final String bankName;
  final String accountHolderName;
  final String accountNumber;

  factory RidePaymentModel.fromMap(Map<String, dynamic> map, String id) {
    final snapshot =
        map[AppFields.payeeBankSnapshot] as Map<String, dynamic>?;
    return RidePaymentModel(
      id: id,
      requestId: map[AppFields.requestId] as String? ?? '',
      bookedByUserId: map[AppFields.bookedByUserId] as String? ?? '',
      qrCodeUrl: (snapshot?[AppFields.qrCodeUrl] as String?) ??
          (map[AppFields.qrCodeUrl] as String?) ??
          '',
      totalAmount: (map[AppFields.totalAmount] as num?)?.toDouble() ?? 0,
      splitAmount: (map[AppFields.splitAmount] as num?)?.toDouble() ?? 0,
      status: map[AppFields.paymentStatus] as String? ?? CarpoolPaymentStatuses.pending,
      confirmedBy: (map[AppFields.confirmedBy] as List<dynamic>? ?? const []).map((value) => value.toString()).toList(),
      createdAt: (map[AppFields.createdAt] as Timestamp?)?.toDate() ?? DateTime.now(),
      bankName: snapshot?[AppFields.bankName] as String? ?? '',
      accountHolderName: snapshot?[AppFields.accountHolderName] as String? ?? '',
      accountNumber: snapshot?[AppFields.accountNumber] as String? ?? '',
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
      // Note: payee_bank_snapshot is NOT written here — it's written
      // server-side by the Cloud Function, never directly by the client.
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
    String? bankName,
    String? accountHolderName,
    String? accountNumber,
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
      bankName: bankName ?? this.bankName,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      accountNumber: accountNumber ?? this.accountNumber,
    );
  }
}