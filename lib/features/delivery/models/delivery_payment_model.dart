import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unipool/core/constants.dart';

class DeliveryPaymentModel {
  const DeliveryPaymentModel({
    required this.id,
    required this.jobId,
    required this.sellerId,
    required this.bookedByUserId,
    required this.qrCodeUrl,
    required this.totalAmount,
    required this.status,
    required this.confirmedBy,
    required this.createdAt,
    this.bankName = '',
    this.accountHolderName = '',
    this.accountNumber = '',
    this.paymentProofUrl = '',
    this.paymentProofMimeType = '',
    this.paidAt,
    this.driverConfirmedAt,
  });

  final String id;
  final String jobId;
  final String sellerId;
  final String bookedByUserId;
  final String qrCodeUrl;
  final double totalAmount;
  final String status;
  final List<String> confirmedBy;
  final DateTime createdAt;

  final String bankName;
  final String accountHolderName;
  final String accountNumber;
  final String paymentProofUrl;
  final String paymentProofMimeType;
  final DateTime? paidAt;
  final DateTime? driverConfirmedAt;

  bool get isSettled =>
      status == DeliveryPaymentStatuses.settled && paymentProofUrl.isNotEmpty;

  bool get driverConfirmedPayment => driverConfirmedAt != null;

  bool get isImageProof =>
      paymentProofMimeType.startsWith('image/') ||
      paymentProofUrl.toLowerCase().contains('.jpg') ||
      paymentProofUrl.toLowerCase().contains('.jpeg') ||
      paymentProofUrl.toLowerCase().contains('.png') ||
      paymentProofUrl.toLowerCase().contains('.webp');

  bool get isPdfProof =>
      paymentProofMimeType == 'application/pdf' ||
      paymentProofUrl.toLowerCase().contains('.pdf');

  factory DeliveryPaymentModel.fromMap(Map<String, dynamic> map, String id) {
    final snapshot =
        map[AppFields.payeeBankSnapshot] as Map<String, dynamic>?;
    return DeliveryPaymentModel(
      id: id,
      jobId: map[AppFields.jobId] as String? ?? '',
      sellerId: map[AppFields.sellerId] as String? ?? '',
      bookedByUserId: map[AppFields.bookedByUserId] as String? ?? '',
      qrCodeUrl: (snapshot?[AppFields.qrCodeUrl] as String?) ??
          (map[AppFields.qrCodeUrl] as String?) ??
          '',
      totalAmount: (map[AppFields.totalAmount] as num?)?.toDouble() ?? 0,
      status: map[AppFields.paymentStatus] as String? ??
          DeliveryPaymentStatuses.pending,
      confirmedBy: (map[AppFields.confirmedBy] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      createdAt:
          (map[AppFields.createdAt] as Timestamp?)?.toDate() ?? DateTime.now(),
      bankName: snapshot?[AppFields.bankName] as String? ?? '',
      accountHolderName:
          snapshot?[AppFields.accountHolderName] as String? ?? '',
      accountNumber: snapshot?[AppFields.accountNumber] as String? ?? '',
      paymentProofUrl: map[AppFields.paymentProofUrl] as String? ?? '',
      paymentProofMimeType:
          map[AppFields.paymentProofMimeType] as String? ?? '',
      paidAt: (map[AppFields.paidAt] as Timestamp?)?.toDate(),
      driverConfirmedAt:
          (map[AppFields.driverConfirmedAt] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      AppFields.jobId: jobId,
      AppFields.sellerId: sellerId,
      AppFields.bookedByUserId: bookedByUserId,
      AppFields.qrCodeUrl: qrCodeUrl,
      AppFields.totalAmount: totalAmount,
      AppFields.paymentStatus: status,
      AppFields.confirmedBy: confirmedBy,
      AppFields.createdAt: Timestamp.fromDate(createdAt),
      if (paymentProofUrl.isNotEmpty) AppFields.paymentProofUrl: paymentProofUrl,
      if (paymentProofMimeType.isNotEmpty)
        AppFields.paymentProofMimeType: paymentProofMimeType,
      if (paidAt != null) AppFields.paidAt: Timestamp.fromDate(paidAt!),
      if (driverConfirmedAt != null)
        AppFields.driverConfirmedAt: Timestamp.fromDate(driverConfirmedAt!),
    };
  }

  DeliveryPaymentModel copyWith({
    String? id,
    String? jobId,
    String? sellerId,
    String? bookedByUserId,
    String? qrCodeUrl,
    double? totalAmount,
    String? status,
    List<String>? confirmedBy,
    DateTime? createdAt,
    String? bankName,
    String? accountHolderName,
    String? accountNumber,
    String? paymentProofUrl,
    String? paymentProofMimeType,
    DateTime? paidAt,
    DateTime? driverConfirmedAt,
  }) {
    return DeliveryPaymentModel(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      sellerId: sellerId ?? this.sellerId,
      bookedByUserId: bookedByUserId ?? this.bookedByUserId,
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      confirmedBy: confirmedBy ?? this.confirmedBy,
      createdAt: createdAt ?? this.createdAt,
      bankName: bankName ?? this.bankName,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      accountNumber: accountNumber ?? this.accountNumber,
      paymentProofUrl: paymentProofUrl ?? this.paymentProofUrl,
      paymentProofMimeType: paymentProofMimeType ?? this.paymentProofMimeType,
      paidAt: paidAt ?? this.paidAt,
      driverConfirmedAt: driverConfirmedAt ?? this.driverConfirmedAt,
    );
  }
}
