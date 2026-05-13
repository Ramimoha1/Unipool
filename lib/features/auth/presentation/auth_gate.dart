import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/auth_repository.dart';
import 'main_authentication_screen.dart';
// Import your post-login screens here:
// import 'package:unipool/features/admin/presentation/admin_dashboard_screen.dart';
// import 'package:unipool/features/home/presentation/home_screen.dart';

/// [AuthGate] sits at the root of the widget tree and listens to Firebase
/// auth state. It routes the user to the correct screen automatically:
///
///   • Not signed in  →  [MainAuthenticationScreen]
///   • Admin          →  [AdminDashboardScreen]
///   • Student/Driver →  [HomeScreen]  (or ProfileScreen for now)
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AuthRepository();

    return StreamBuilder<User?>(
      stream: repo.authStateChanges,
      builder: (context, snapshot) {
        // Still connecting to Firebase
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        final user = snapshot.data;

        // Not logged in → show auth flow
        if (user == null) {
          return const MainAuthenticationScreen();
        }

        // Logged in → resolve user type and route accordingly
        return FutureBuilder<String?>(
          future: repo.getUserType(user.uid),
          builder: (context, typeSnapshot) {
            if (typeSnapshot.connectionState == ConnectionState.waiting) {
              return const _SplashScreen();
            }

            final userType = typeSnapshot.data ?? 'student';

            if (userType == 'admin') {
              // TODO: replace with AdminDashboardScreen() once imported
              return const _PlaceholderScreen(
                label: 'Admin Dashboard',
                color: Color(0xFFD32F2F),
              );
            }

            // Default: student / driver / driver_candidate
            // TODO: replace with HomeScreen() or your main tab navigator
            return const _PlaceholderScreen(
              label: 'Student Home',
              color: Color(0xFF1A9B8A),
            );
          },
        );
      },
    );
  }
}

// ─── Splash ───────────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1A9B8A),
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

// ─── Placeholder (remove when real screens are wired up) ─────────────────────

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: color,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => AuthRepository().signOut(),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white24,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}
