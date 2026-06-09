import 'package:flutter/material.dart';

class PaymentBanner extends StatelessWidget {
  const PaymentBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w600)),
    );
  }
}