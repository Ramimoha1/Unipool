import 'package:flutter/material.dart';
import 'package:unipool/features/auth/presentation/auth_gate.dart';

class BannedScreen extends StatelessWidget {
  final String bannedStatus;
  final String bannedReason;
  final DateTime? banExpiresAt;

  const BannedScreen({
    super.key,
    required this.bannedStatus,
    required this.bannedReason,
    this.banExpiresAt,
  });

  String _banTypeLabel(String type) {
    switch (type) {
      case 'permanent':
        return 'Permanently Banned';
      case 'temporary':
        return 'Temporarily Suspended';
      case 'until_payment':
        return 'Suspended (Awaiting Payment)';
      default:
        return 'Account Suspended';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Account Suspended', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFD32F2F),
        automaticallyImplyLeading: false, // Prevent going back
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.block,
                color: Color(0xFFD32F2F),
                size: 80,
              ),
              const SizedBox(height: 24),
              const Text(
                'Your account has been suspended.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A2332),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: ${_banTypeLabel(bannedStatus)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Reason: $bannedReason',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                    if (banExpiresAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Expires: ${banExpiresAt!.year}-${banExpiresAt!.month.toString().padLeft(2, '0')}-${banExpiresAt!.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // Since we already signed out in AuthGate, going to AuthGate will route to Login
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthGate()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A9B8A), // Teal
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Back to Login', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
