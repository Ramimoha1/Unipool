import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/auth_repository.dart';
import 'main_authentication_screen.dart';
import 'package:unipool/features/profile/presentation/profile_screen.dart';
import 'package:unipool/features/admin/presentation/admin_dashboard_screen.dart';

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

        // Logged in → route by role (admin vs everyone else)
        return FutureBuilder<bool>(
          future: repo.isAdmin(user.uid),
          builder: (context, adminSnapshot) {
            if (adminSnapshot.connectionState == ConnectionState.waiting) {
              return const _SplashScreen();
            }

            if (adminSnapshot.data == true) {
              return const AdminDashboardScreen();
            }

            return const ProfileScreen();
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
