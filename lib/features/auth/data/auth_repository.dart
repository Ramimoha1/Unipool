import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  // ─── Stream ───────────────────────────────────────────────────────────────

  /// Emits the current [User] whenever auth state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // ─── Registration ─────────────────────────────────────────────────────────

  /// Registers a new student and stores their profile in Firestore.
  /// Optionally uploads a matric card photo to Firebase Storage.
  Future<User> registerStudent({
    required String fullName,
    required String email,
    required String password,
    required String university,
    required String matricNumber,
    XFile? matricCardFile,
  }) async {
    // 1. Create Firebase Auth account
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;

    // 2. Upload matric card if provided
    String? matricCardUrl;
    if (matricCardFile != null) {
      matricCardUrl = await _uploadMatricCard(
        userId: user.uid,
        file: matricCardFile,
      );
    }

    // 3. Update display name
    await user.updateDisplayName(fullName.trim());

    // 4. Write user document to Firestore
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'fullName': fullName.trim(),
      'email': email.trim().toLowerCase(),
      'phoneNumber': '',
      'roles': ['student'],
      'matricNumber': matricNumber.trim(),
      'university': university.trim(),
      'matricCardUrl': matricCardUrl,
      'profilePhotoUrl': null,
      'verificationStatus': 'unverified',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return user;
  }

  // ─── Login ────────────────────────────────────────────────────────────────

  /// Signs in with email and password. Returns the [User] on success.
  Future<User> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user!;
  }

  /// Signs in as admin. Verifies the user has `'admin'` in their `roles` array in Firestore.
  Future<User> signInAsAdmin({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;

    // Verify admin role in Firestore
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();
    final roles = (data?['roles'] as List<dynamic>?)?.cast<String>() ?? [];
    if (data == null || !roles.contains('admin')) {
      await _auth.signOut();
      throw Exception('Access denied. This account does not have admin privileges.');
    }

    return user;
  }

  // ─── Password Reset ───────────────────────────────────────────────────────

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ─── Sign Out ─────────────────────────────────────────────────────────────

  Future<void> signOut() => _auth.signOut();

  // ─── Roles Lookup ─────────────────────────────────────────────────────────

  /// Returns the roles list for the given uid from Firestore.
  Future<List<String>> getUserRoles(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final roles = (doc.data()?['roles'] as List<dynamic>?)?.cast<String>() ?? [];
    return roles;
  }

  // ─── Private Helpers ──────────────────────────────────────────────────────

  Future<String> _uploadMatricCard({
    required String userId,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();
    final mimeType = file.mimeType ?? 'image/jpeg';
    final ext = file.name.split('.').last.toLowerCase();
    final ref = _storage
        .ref()
        .child('matric_cards/$userId/matric_card_${DateTime.now().millisecondsSinceEpoch}.$ext');
    final task = await ref.putData(bytes, SettableMetadata(contentType: mimeType));
    return task.ref.getDownloadURL();
  }
}