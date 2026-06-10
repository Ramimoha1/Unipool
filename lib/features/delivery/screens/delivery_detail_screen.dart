import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:unipool/core/widgets/app_bottom_nav.dart';
import '../models/delivery_job_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/delivery_provider.dart';

class DeliveryDetailScreen extends StatelessWidget {
  const DeliveryDetailScreen({super.key, required this.job});

  final DeliveryJobModel job;

  static const Color _purple = Color(0xFF9C27B0);
  static const Color _greenBadgeBg = Color(0xFFE8F5E9);
  static const Color _greenBadgeText = Color(0xFF2E7D32);
  static const Color _textPrimary = Color(0xFF1A2332);
  static const Color _textSecondary = Color(0xFF8A96A3);

  void _applyForJob(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first.')),
      );
      return;
    }
    
    if (user.uid == job.sellerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot apply for your own job.')),
      );
      return;
    }

    try {
      await context.read<DeliveryProvider>().applyToJob(job.id, user.uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Applied successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to apply: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final startFormat = DateFormat('h:mm a').format(job.timeWindowStart);
    final endFormat = DateFormat('h:mm a').format(job.timeWindowEnd);
    final initial = job.sellerId.isNotEmpty ? job.sellerId[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF1A2332)),
        title: const Text(
          'Delivery Details',
          style: TextStyle(
            color: Color(0xFF1A2332),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and Price Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.inventory_2_outlined, color: _purple, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${job.quantity} items',
                          style: const TextStyle(
                            fontSize: 14,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _greenBadgeBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '\$${job.price.toInt()}',
                      style: const TextStyle(
                        color: _greenBadgeText,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Route Stops
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildRouteStop(
                    title: 'Pickup',
                    subtitle: job.pickupLabel,
                    icon: Icons.location_on,
                    iconColor: _purple,
                    isFirst: true,
                    isLast: job.deliveryStops.isEmpty,
                  ),
                  for (int i = 0; i < job.deliveryStops.length; i++)
                    _buildRouteStop(
                      title: 'Stop ${i + 1}',
                      subtitle: job.deliveryStops[i]['label'],
                      icon: Icons.flag,
                      iconColor: const Color(0xFFF59E0B),
                      isFirst: false,
                      isLast: i == job.deliveryStops.length - 1,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Time Window
            const Text(
              'Time Window',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: _textSecondary),
                  const SizedBox(width: 12),
                  Text(
                    '$startFormat - $endFormat',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Poster Info
            const Text(
              'Poster Info',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _purple.withOpacity(0.1),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: _purple,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.sellerId.isNotEmpty ? job.sellerId : 'Unknown',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Seller',
                          style: TextStyle(
                            fontSize: 13,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Apply Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => _applyForJob(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Apply for This Job',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  Widget _buildRouteStop({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isFirst,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                if (!isFirst)
                  Container(width: 2, height: 16, color: const Color(0xFFD9E2EC))
                else
                  const SizedBox(height: 16),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: const Color(0xFFD9E2EC)),
                  )
                else
                  const SizedBox(height: 16),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
