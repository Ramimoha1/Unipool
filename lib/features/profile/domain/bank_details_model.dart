import 'package:unipool/core/constants.dart';

/// Represents a user's saved bank / payment details.
///
/// Stored as a nested map (`bankDetails`) on the Firestore `users/{uid}` document.
class BankDetailsModel {
  const BankDetailsModel({
    this.bankName = '',
    this.accountHolderName = '',
    this.accountNumber = '',
    this.qrCodeUrl = '',
  });

  final String bankName;
  final String accountHolderName;
  final String accountNumber;
  final String qrCodeUrl;

  /// Whether the user has entered any payment information at all.
  bool get isEmpty =>
      bankName.isEmpty &&
      accountHolderName.isEmpty &&
      accountNumber.isEmpty &&
      qrCodeUrl.isEmpty;

  bool get isNotEmpty => !isEmpty;

  factory BankDetailsModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const BankDetailsModel();
    return BankDetailsModel(
      bankName: map[AppFields.bankName] as String? ?? '',
      accountHolderName: map[AppFields.accountHolderName] as String? ?? '',
      accountNumber: map[AppFields.accountNumber] as String? ?? '',
      qrCodeUrl: map[AppFields.qrCodeUrl] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      AppFields.bankName: bankName,
      AppFields.accountHolderName: accountHolderName,
      AppFields.accountNumber: accountNumber,
      AppFields.qrCodeUrl: qrCodeUrl,
    };
  }

  BankDetailsModel copyWith({
    String? bankName,
    String? accountHolderName,
    String? accountNumber,
    String? qrCodeUrl,
  }) {
    return BankDetailsModel(
      bankName: bankName ?? this.bankName,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      accountNumber: accountNumber ?? this.accountNumber,
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
    );
  }
}
