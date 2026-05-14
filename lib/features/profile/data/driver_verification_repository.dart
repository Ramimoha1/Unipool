import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../domain/driver_application.dart';

class DriverVerificationRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  DriverVerificationRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  /// Upload a document image to Firebase Storage.
  /// Uses [XFile.readAsBytes] so it works on web AND mobile.
  /// Returns the download URL.
  Future<String> uploadDocument({
    required String userId,
    required XFile file,
    required String docType, // 'student_card' or 'driver_license'
  }) async {
    final bytes = await file.readAsBytes();
    final mimeType = file.mimeType ?? 'image/jpeg';
    final ext = file.name.split('.').last.toLowerCase();

    final ref = _storage
        .ref()
        .child(
            'verification_docs/$userId/${docType}_${DateTime.now().millisecondsSinceEpoch}.$ext');

    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: mimeType),
    );
    return task.ref.getDownloadURL();
  }

  /// Submit a new driver verification application to Firestore.
  Future<void> submitApplication({
    required String userId,
    required String studentCardUrl,
    required String driverLicenseUrl,
    required VehicleInfo vehicleInfo,
  }) async {
    // Check if a pending application already exists to avoid duplicates.
    final existing = await _firestore
        .collection('driverApplications')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('You already have a pending application under review.');
    }

    final application = DriverApplication(
      userId: userId,
      status: DriverApplicationStatus.pending,
      studentCardUrl: studentCardUrl,
      driverLicenseUrl: driverLicenseUrl,
      vehicleInfo: vehicleInfo,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('driverApplications')
        .add(application.toMap());

    // Update the user's verificationStatus to reflect a pending review.
    await _firestore.collection('users').doc(userId).update({
      'verificationStatus': 'pending',
      'roles': FieldValue.arrayUnion(['driver_candidate']),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Fetch the latest application for a user.
  Future<DriverApplication?> getLatestApplication(String userId) async {
    final snapshot = await _firestore
        .collection('driverApplications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return DriverApplication.fromFirestore(snapshot.docs.first);
  }

  /// Stream user document to reflect real-time verificationStatus changes.
  Stream<Map<String, dynamic>?> userStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snap) => snap.data());
  }
}