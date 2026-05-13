import 'package:flutter/material.dart';
import '../data/auth_repository.dart';

/// Admin login screen matching Figma Image 4.
/// Red theme, shield icon, admin role verification, restricted area notice.
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  // ─── Constants ───────────────────────────────────────────────────────────
  static const Color _red = Color(0xFFDC2626);
  static const Color _redLight = Color(0xFFFEF2F2);
  static const Color _redBorder = Color(0xFFFECACA);
  static const Color _textDark = Color(0xFF1A2332);
  static const Color _textMuted = Color(0xFF9CA3AF);
  static const Color _border = Color(0xFFE5EAF0);

  // ─── State ───────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;

  final _repo = AuthRepository();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ─── Actions ─────────────────────────────────────────────────────────────

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await _repo.signInAsAdmin(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
      );
      // AuthGate will detect userType == 'admin' and route to AdminDashboardScreen.
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
        backgroundColor: _red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _friendlyMessage(String raw) {
    if (raw.contains('user-not-found') ||
        raw.contains('wrong-password') ||
        raw.contains('invalid-credential')) {
      return 'Incorrect email or password.';
    }
    if (raw.contains('admin privileges')) {
      return 'Access denied. This account is not an admin.';
    }
    if (raw.contains('too-many-requests')) {
      return 'Too many attempts. Please wait a moment.';
    }
    if (raw.contains('user-disabled')) return 'This account has been disabled.';
    return raw.replaceAll('Exception: ', '');
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
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // ── Header row ───────────────────────────────────────────
                Row(
                  children: [
                    // Shield icon circle
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _redLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: _red,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Admin Login',
                          style: TextStyle(
                            color: _textDark,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Platform moderator access',
                          style: TextStyle(
                            color: _textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 36),

                // ── Admin Email ──────────────────────────────────────────
                _FieldLabel('Admin Email'),
                _InputField(
                  controller: _emailCtrl,
                  hint: 'admin@unipool.sg',
                  prefixIcon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  accentColor: _red,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // ── Password ─────────────────────────────────────────────
                _FieldLabel('Password'),
                _InputField(
                  controller: _passwordCtrl,
                  hint: 'Enter your password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscure,
                  accentColor: _red,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    return null;
                  },
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: _textMuted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Log In as Admin Button ───────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
                      disabledBackgroundColor: _red.withOpacity(0.6),
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
                            'Log In as Admin',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Restricted area notice ───────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _redLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _redBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Note: ',
                        style: TextStyle(
                          color: _red,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'This is a restricted area for platform moderators only. Unauthorized access is prohibited.',
                          style: TextStyle(
                            color: Color(0xFF991B1B),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Reusable Widgets ─────────────────────────────────────────────────────────

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
    this.accentColor = const Color(0xFF1A9B8A),
  });

  final TextEditingController controller;
  final String hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Color accentColor;

  static const Color _border = Color(0xFFE5EAF0);
  static const Color _textMuted = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: Color(0xFF1A2332)),
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
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFDC2626), width: 1.5),
        ),
      ),
    );
  }
}
