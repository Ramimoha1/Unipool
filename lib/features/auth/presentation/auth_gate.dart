import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/auth_repository.dart';
import 'main_authentication_screen.dart';
import 'package:unipool/features/profile/presentation/profile_screen.dart';
import 'package:unipool/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:unipool/features/auth/presentation/banned_screen.dart';

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

        // Logged in → route by role and check ban status
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const _SplashScreen();
            }

            final data = userSnapshot.data?.data() as Map<String, dynamic>?;

            if (data != null && data['isBanned'] == true) {
              // Prevent stale cache from incorrectly signing out users whose bans were lifted.
              // Wait for the server snapshot if the local cache says they are banned.
              if (userSnapshot.data?.metadata.isFromCache == true) {
                return const _SplashScreen();
              }
              final expiresAt = (data['banExpiresAt'] as Timestamp?)?.toDate();
              
              if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
                // Auto-unban expired temporary suspensions
                FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                  'isBanned': false,
                  'isActive': true,
                  'banType': FieldValue.delete(),
                  'banReason': FieldValue.delete(),
                  'bannedStatus': FieldValue.delete(),
                  'bannedReason': FieldValue.delete(),
                  'bannedAt': FieldValue.delete(),
                  'banExpiresAt': FieldValue.delete(),
                  'bannedBy': FieldValue.delete(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                // The stream will emit a new snapshot and rebuild automatically
                return const _SplashScreen();
              }

              // Active ban -> Sign out immediately and show BannedScreen
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => BannedScreen(
                        bannedStatus: data['bannedStatus'] ?? data['banType'] ?? 'permanent',
                        bannedReason: data['bannedReason'] ?? data['banReason'] ?? 'Violation of terms',
                        banExpiresAt: expiresAt,
                      ),
                    ),
                    (route) => false,
                  );
                }
              });
              return const _SplashScreen();
            }

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
