import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/auth_repository.dart';

/// Registration screen matching Figma Image 2.
/// Collects: full name, university email, university, matric number,
/// matric card photo. Writes to Firebase Auth + Firestore via [AuthRepository].
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // ─── Constants ───────────────────────────────────────────────────────────
  static const Color _teal = Color(0xFF1A9B8A);
  static const Color _border = Color(0xFFE5EAF0);
  static const Color _textDark = Color(0xFF1A2332);
  static const Color _textMuted = Color(0xFF9CA3AF);
  static const Color _errorRed = Color(0xFFDC2626);

  // ─── State ───────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _universityCtrl = TextEditingController();
  final _matricCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  File? _matricCardFile;
  String? _matricCardName;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  final _repo = AuthRepository();

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _universityCtrl.dispose();
    _matricCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ─── Actions ─────────────────────────────────────────────────────────────

  Future<void> _pickMatricCard() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked == null) return;
    setState(() {
      _matricCardFile = File(picked.path);
      _matricCardName = picked.name;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _repo.registerStudent(
        fullName: _fullNameCtrl.text,
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        university: _universityCtrl.text,
        matricNumber: _matricCtrl.text,
        matricCardFile: _matricCardFile,
      );
      // AuthGate will pick up the new user and route automatically.
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on Exception catch (e) {
      _showError(_friendlyMessage(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _friendlyMessage(String raw) {
    if (raw.contains('email-already-in-use')) {
      return 'An account with this email already exists.';
    }
    if (raw.contains('weak-password')) return 'Password is too weak.';
    if (raw.contains('invalid-email')) return 'Please enter a valid email.';
    return raw.replaceAll('Exception: ', '');
  }

  // ─── Validators ──────────────────────────────────────────────────────────

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final lower = v.trim().toLowerCase();
    if (!lower.contains('@')) return 'Enter a valid email';
    // Optionally enforce university domain:
    // if (!lower.endsWith('.edu') && !lower.endsWith('.edu.my')) {
    //   return 'Must be a university email';
    // }
    return null;
  }

  String? _validateRequired(String? v, String field) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v != _passwordCtrl.text) return 'Passwords do not match';
    return null;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: _textDark),
        title: const Text(
          'Create Account',
          style: TextStyle(
            color: _textDark,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Join the UniPool community',
                  style: TextStyle(color: _textMuted, fontSize: 14),
                ),
                const SizedBox(height: 28),

                // Full Name
                _FieldLabel('Full Name'),
                _InputField(
                  controller: _fullNameCtrl,
                  hint: 'John Doe',
                  prefixIcon: Icons.person_outline,
                  validator: (v) => _validateRequired(v, 'Full name'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 18),

                // University Email
                _FieldLabel('University Email'),
                _InputField(
                  controller: _emailCtrl,
                  hint: 'your.email@university.edu',
                  prefixIcon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4, left: 2),
                  child: Text(
                    'Must be a valid university email',
                    style: TextStyle(color: _textMuted, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 18),

                // University
                _FieldLabel('University'),
                _InputField(
                  controller: _universityCtrl,
                  hint: 'e.g., Universiti Putra Malaysia',
                  prefixIcon: Icons.school_outlined,
                  validator: (v) => _validateRequired(v, 'University'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 18),

                // Matric Number
                _FieldLabel('Matric Number'),
                _InputField(
                  controller: _matricCtrl,
                  hint: 'e.g., A0123456X',
                  validator: (v) => _validateRequired(v, 'Matric number'),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 18),

                // Password
                _FieldLabel('Password'),
                _InputField(
                  controller: _passwordCtrl,
                  hint: 'At least 8 characters',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  validator: _validatePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: _textMuted,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 18),

                // Confirm Password
                _FieldLabel('Confirm Password'),
                _InputField(
                  controller: _confirmCtrl,
                  hint: 'Re-enter your password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscureConfirm,
                  validator: _validateConfirm,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: _textMuted,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                const SizedBox(height: 18),

                // Matric Card Photo
                _FieldLabel('Matric Card Photo'),
                const SizedBox(height: 6),
                _MatricCardUpload(
                  fileName: _matricCardName,
                  onTap: _pickMatricCard,
                ),

                const SizedBox(height: 32),

                // Create Account Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      disabledBackgroundColor: _teal.withOpacity(0.6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // Already have account
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(color: _textMuted, fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Log in',
                        style: TextStyle(
                          color: _teal,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Matric Card Upload Widget ────────────────────────────────────────────────

class _MatricCardUpload extends StatelessWidget {
  const _MatricCardUpload({this.fileName, required this.onTap});

  final String? fileName;
  final VoidCallback onTap;

  static const Color _teal = Color(0xFF1A9B8A);
  static const Color _border = Color(0xFFD1D5DB);
  static const Color _textMuted = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: _border, width: 1.5),
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFF9FAFB),
      ),
      child: Column(
        children: [
          Icon(
            Icons.upload_outlined,
            size: 32,
            color: fileName != null ? _teal : _textMuted,
          ),
          const SizedBox(height: 8),
          Text(
            fileName ?? 'Upload your matric card',
            style: TextStyle(
              fontSize: 14,
              fontWeight: fileName != null ? FontWeight.w500 : FontWeight.normal,
              color: fileName != null ? const Color(0xFF374151) : _textMuted,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (fileName == null)
            const Text(
              'For verification purposes',
              style: TextStyle(color: _textMuted, fontSize: 12),
            ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              fileName != null ? 'Change File' : 'Choose File',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable Field Components ────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF374151),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;

  static const Color _border = Color(0xFFE5EAF0);
  static const Color _textMuted = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        color: Color(0xFF1A2332),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textMuted, fontSize: 14),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: _textMuted, size: 20)
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1A9B8A), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
        ),
      ),
    );
  }
}
