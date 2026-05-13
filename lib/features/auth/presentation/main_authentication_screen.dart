import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'admin_login_screen.dart';

/// Landing screen shown to unauthenticated users.
/// Matches Figma Image 1: gradient background, UniPool branding,
/// feature highlights, and three CTA buttons.
class MainAuthenticationScreen extends StatelessWidget {
  const MainAuthenticationScreen({super.key});

  // ─── Brand colours ───────────────────────────────────────────────────────
  static const Color _gradientTop = Color(0xFF4DB6B0);    // teal-mint
  static const Color _gradientMid = Color(0xFF5B72C8);    // periwinkle
  static const Color _gradientBot = Color(0xFF7C4DB8);    // purple
  static const Color _teal = Color(0xFF1A9B8A);
  static const Color _adminPurple = Color(0xFF7C4DB8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_gradientTop, _gradientMid, _gradientBot],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // ── Logo circle ──────────────────────────────────────────
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_car_outlined,
                    color: _teal,
                    size: 40,
                  ),
                ),

                const SizedBox(height: 20),

                // ── Brand name ───────────────────────────────────────────
                const Text(
                  'UniPool',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  'Student carpooling & delivery platform',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 48),

                // ── Feature highlights ───────────────────────────────────
                _FeatureRow(
                  icon: Icons.directions_car_outlined,
                  title: 'Share Rides',
                  subtitle: 'Save money on transportation',
                ),
                const SizedBox(height: 20),
                _FeatureRow(
                  icon: Icons.inventory_2_outlined,
                  title: 'Earn with Deliveries',
                  subtitle: 'Make money on your route',
                ),
                const SizedBox(height: 20),
                _FeatureRow(
                  icon: Icons.shield_outlined,
                  title: 'Students Only',
                  subtitle: 'Safe & verified community',
                ),

                const Spacer(),

                // ── CTA buttons ──────────────────────────────────────────
                _PrimaryButton(
                  label: 'Create Account',
                  textColor: _teal,
                  backgroundColor: Colors.white,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const RegisterScreen()),
                  ),
                ),

                const SizedBox(height: 12),

                _OutlineButton(
                  label: 'Log In',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                ),

                const SizedBox(height: 12),

                _PrimaryButton(
                  label: 'Admin Login',
                  textColor: Colors.white,
                  backgroundColor: _adminPurple,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminLoginScreen()),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Feature Row ──────────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Shared Button Widgets ────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    required this.onTap,
  });

  final String label;
  final Color textColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
