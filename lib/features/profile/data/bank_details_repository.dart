import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:unipool/core/constants.dart';
import '../domain/bank_details_model.dart';

/// Repository for reading / writing bank payment details.
///
/// IMPORTANT: bank details now live in their own top-level collection
/// `bank_details/{uid}` — NOT nested on `users/{uid}` anymore. The old
/// location was readable by every signed-in user (see firestore.rules
/// before this change), which exposed account numbers to anyone in the
/// app. The new collection is locked to owner-only read/write.
///
/// Other users never read this collection directly. When a payment is
/// triggered (carpool or delivery), a Cloud Function copies a snapshot
/// of the payee's bank details onto the payment document, which already
/// has correct member-scoped access rules. See `copyPayeeBankDetails`
/// in functions/src/index.ts.
class BankDetailsRepository {
  BankDetailsRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  DocumentReference<Map<String, dynamic>> _doc(String userId) =>
      _firestore.collection(AppCollections.bankDetails).doc(userId);

  // ── Read ─────────────────────────────────────────────────────────────────

  /// One-shot fetch of the current bank details. Only callable for your
  /// own uid under the new rules — calling this with someone else's uid
  /// will throw a permission-denied error, which is intentional.
  Future<BankDetailsModel> getBankDetails(String userId) async {
    final snap = await _doc(userId).get();
    return BankDetailsModel.fromMap(snap.data());
  }

  /// Real-time stream of bank details changes.
  Stream<BankDetailsModel> bankDetailsStream(String userId) {
    return _doc(userId).snapshots().map(
          (snap) => BankDetailsModel.fromMap(snap.data()),
        );
  }

  // ── Write ────────────────────────────────────────────────────────────────

  /// Saves (or creates) the bank details document for this user.
  Future<void> saveBankDetails(String userId, BankDetailsModel details) async {
    await _doc(userId).set({
      ...details.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Uploads a QR code image to Firebase Storage and returns the download URL.
  ///
  /// Images are stored at `user_qr_codes/{userId}/qr.{ext}`, which matches
  /// the existing Firebase Storage security rule for QR codes.
  Future<String> uploadQrImage(String userId, XFile file) async {
    final bytes = await file.readAsBytes();
    final mimeType = file.mimeType ?? 'image/jpeg';
    final ext = file.name.split('.').last.toLowerCase();

    final ref = _storage.ref().child('user_qr_codes/$userId/qr.$ext');

    await ref.putData(bytes, SettableMetadata(contentType: mimeType));
    return ref.getDownloadURL();
  }

  /// Removes all bank details for this user.
  Future<void> deleteBankDetails(String userId) async {
    await _doc(userId).delete();
  }
}