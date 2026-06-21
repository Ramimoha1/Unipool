import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:unipool/core/constants.dart';
import '../domain/bank_details_model.dart';

/// Repository for reading / writing bank payment details on the user document.
///
/// Bank details are stored as a nested map at `users/{uid}.bankDetails`.
class BankDetailsRepository {
  BankDetailsRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) =>
      _firestore.collection(AppCollections.users).doc(userId);

  // ── Read ─────────────────────────────────────────────────────────────────

  /// One-shot fetch of the current bank details.
  Future<BankDetailsModel> getBankDetails(String userId) async {
    final snap = await _userDoc(userId).get();
    final data = snap.data();
    if (data == null) return const BankDetailsModel();
    return BankDetailsModel.fromMap(
      data[AppFields.bankDetails] as Map<String, dynamic>?,
    );
  }

  /// Real-time stream of bank details changes.
  Stream<BankDetailsModel> bankDetailsStream(String userId) {
    return _userDoc(userId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return const BankDetailsModel();
      return BankDetailsModel.fromMap(
        data[AppFields.bankDetails] as Map<String, dynamic>?,
      );
    });
  }

  // ── Write ────────────────────────────────────────────────────────────────

  /// Saves (or updates) the bank details nested map on the user document.
  ///
  /// Also keeps the legacy top-level `qr_code_url` field in sync so that
  /// existing carpool payment logic continues to work without modification.
  Future<void> saveBankDetails(String userId, BankDetailsModel details) async {
    await _userDoc(userId).update({
      AppFields.bankDetails: details.toMap(),
      // Keep the legacy field in sync for backward compatibility
      AppFields.userQrCodeUrlSnake: details.qrCodeUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Uploads a QR code image to Firebase Storage and returns the download URL.
  ///
  /// Images are stored at `user_qr_codes/{userId}/qr.{ext}`, which matches
  /// the existing Firebase Storage security rule for QR codes.
  Future<String> uploadQrImage(String userId, XFile file) async {
    final bytes = await file.readAsBytes();
    final mimeType = file.mimeType ?? 'image/jpeg';
    final ext = file.name.split('.').last.toLowerCase();

    final ref = _storage
        .ref()
        .child('user_qr_codes/$userId/qr.$ext');

    await ref.putData(bytes, SettableMetadata(contentType: mimeType));
    return ref.getDownloadURL();
  }

  /// Removes all bank details from the user document.
  Future<void> deleteBankDetails(String userId) async {
    await _userDoc(userId).update({
      AppFields.bankDetails: FieldValue.delete(),
      AppFields.userQrCodeUrlSnake: FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
