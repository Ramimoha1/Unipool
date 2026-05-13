import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../data/driver_verification_repository.dart';
import 'package:image_picker/image_picker.dart';

class ApplyDriverScreen extends StatefulWidget {
  const ApplyDriverScreen({super.key});

  @override
  State<ApplyDriverScreen> createState() => _ApplyDriverScreenState();
}

class _ApplyDriverScreenState extends State<ApplyDriverScreen> {
  // ─── Constants ───────────────────────────────────────────────────────────
  static const Color _teal = Color(0xFF1A9B8A);
  static const Color _tealLight = Color(0xFFE8F7F5);
  static const Color _amber = Color(0xFFFFC107);
  static const Color _textDark = Color(0xFF1A2332);
  static const Color _textMuted = Color(0xFF8A96A3);
  static const Color _border = Color(0xFFE5EAF0);
  static const Color _bgPage = Color(0xFFF7F9FC);

  // ─── State ───────────────────────────────────────────────────────────────
  File? _studentCardFile;
  File? _driverLicenseFile;
  bool _isSubmitting = false;
  String? _studentCardName;
  String? _driverLicenseName;

  final _repo = DriverVerificationRepository(
    firestore: FirebaseFirestore.instance,
    storage: FirebaseStorage.instance,
  );

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// Opens a simple file picker dialog that lets the user pick a JPG or PNG
  /// from the device gallery.  In a real project replace this body with
  /// `image_picker` calls – the signature stays the same.
  Future<void> _pickFile(bool isStudentCard) async {
    // ── REAL IMPLEMENTATION ──────────────────────────────────────────────
    // Uncomment the block below and add image_picker to pubspec.yaml.
    //
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked == null) return;
    final file = File(picked.path);
    setState(() {
      if (isStudentCard) {
        _studentCardFile = file;
        _studentCardName = picked.name;
      } else {
        _driverLicenseFile = file;
        _driverLicenseName = picked.name;
      }
    });
    // ─────────────────────────────────────────────────────────────────────

    // STUB: show a snackbar until image_picker is wired up.
    // _showSnack(
    //   'Add image_picker to pubspec.yaml and uncomment _pickFile body.',
    //   isError: false,
    // );
  }

  Future<void> _submit() async {
    if (_studentCardFile == null || _driverLicenseFile == null) {
      _showSnack('Please upload both documents before submitting.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('You must be logged in to submit an application.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final studentCardUrl = await _repo.uploadDocument(
        userId: user.uid,
        file: _studentCardFile!,
        docType: 'student_card',
      );
      final driverLicenseUrl = await _repo.uploadDocument(
        userId: user.uid,
        file: _driverLicenseFile!,
        docType: 'driver_license',
      );

      await _repo.submitApplication(
        userId: user.uid,
        studentCardUrl: studentCardUrl,
        driverLicenseUrl: driverLicenseUrl,
      );

      if (!mounted) return;
      _showSnack('Application submitted! We\'ll review it within 24–48 hours.', isError: false);
      Navigator.of(context).pop(true); // pop with `true` so Profile refreshes
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : _teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      appBar: AppBar(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Apply to be a Driver',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoBanner(),
            const SizedBox(height: 24),
            _SectionLabel('Student Matric Card'),
            const SizedBox(height: 10),
            _UploadCard(
              label: 'Upload your matric card',
              hint: 'JPG, PNG (Max 2MB)',
              fileName: _studentCardName,
              onChoose: () => _pickFile(true),
            ),
            const SizedBox(height: 20),
            _SectionLabel("Driver's License"),
            const SizedBox(height: 10),
            _UploadCard(
              label: "Upload your driver's license",
              hint: 'JPG, PNG (Max 2MB)',
              fileName: _driverLicenseName,
              onChoose: () => _pickFile(false),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _teal.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Application',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  static const Color _teal = Color(0xFF1A9B8A);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF4FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFD3F5), width: 1),
      ),
      child: const Text(
        'To become a verified driver, please submit the following documents. '
        'Our admin team will review your application within 24–48 hours.',
        style: TextStyle(
          fontSize: 13.5,
          color: Color(0xFF3A5A99),
          height: 1.5,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A2332),
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.label,
    required this.hint,
    required this.onChoose,
    this.fileName,
  });

  final String label;
  final String hint;
  final VoidCallback onChoose;
  final String? fileName;

  static const Color _teal = Color(0xFF1A9B8A);
  static const Color _border = Color(0xFFE5EAF0);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: fileName != null ? _teal.withOpacity(0.5) : _border,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            fileName != null ? Icons.check_circle_outline : Icons.upload_outlined,
            size: 32,
            color: fileName != null ? _teal : const Color(0xFF8A96A3),
          ),
          const SizedBox(height: 10),
          Text(
            fileName ?? label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: fileName != null ? _teal : const Color(0xFF4A5568),
              fontWeight: fileName != null ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          if (fileName == null) ...[
            const SizedBox(height: 4),
            Text(
              hint,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF8A96A3)),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: onChoose,
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                fileName != null ? 'Change File' : 'Choose File',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
