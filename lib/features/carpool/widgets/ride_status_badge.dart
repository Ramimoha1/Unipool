import 'package:flutter/material.dart';

class RideStatusBadge extends StatelessWidget {
  const RideStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = switch (status) {
      'open' => (const Color(0xFFE7F8F5), const Color(0xFF0F9D8A)),
      'confirmed' => (const Color(0xFFEAF3FF), const Color(0xFF2D6CDF)),
      'in_progress' => (const Color(0xFFFFF4DB), const Color(0xFFB76E00)),
      'completed' => (const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
      'cancelled' => (const Color(0xFFFFEBEE), const Color(0xFFC62828)),
      _ => (const Color(0xFFF1F5F9), const Color(0xFF475569)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: colors.$2, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}