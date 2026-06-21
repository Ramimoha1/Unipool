import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/delivery_job_model.dart';

class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job, required this.onTap});

  final DeliveryJobModel job;
  final VoidCallback onTap;

  static const Color _purple = Color(0xFF9C27B0);
  static const Color _greenBadgeBg = Color(0xFFE8F5E9);
  static const Color _greenBadgeText = Color(0xFF2E7D32);
  static const Color _textPrimary = Color(0xFF1A2332);
  static const Color _textSecondary = Color(0xFF8A96A3);

  @override
  Widget build(BuildContext context) {
    // Format stops text
    String stopsText = '';
    if (job.deliveryStops.isNotEmpty) {
      stopsText = 'Stops: ${job.deliveryStops.map((s) => s['label']).join(', ')}';
    }

    // Format time window
    final startFormat = DateFormat('h:mm a').format(job.timeWindowStart);
    final endFormat = DateFormat('h:mm a').format(job.timeWindowEnd);


    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Title and Price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    (job.items.isNotEmpty && job.items.first['photo_url'] != null)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              job.items.first['photo_url'] as String,
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.inventory_2_outlined, color: _purple, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        job.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _greenBadgeBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'RM${job.price.toInt()}',
                        style: const TextStyle(
                          color: _greenBadgeText,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Pickup Location
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, color: _purple, size: 18),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pickup: ${job.pickupLabel}',
                            style: const TextStyle(
                              color: _textPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          if (stopsText.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              stopsText,
                              style: const TextStyle(
                                color: _textSecondary,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Time Window
                Row(
                  children: [
                    const Icon(Icons.access_time, color: _textSecondary, size: 18),
                    const SizedBox(width: 14),
                    Text(
                      '$startFormat - $endFormat',
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFEEF2F7)),
                const SizedBox(height: 12),
                
                // Poster Info Footer
                FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance.collection('users').doc(job.sellerId).get(),
                  builder: (context, snap) {
                    final data = snap.data?.data();
                    final sellerName = (data?['fullName'] as String?)?.trim() ?? (job.sellerId.isNotEmpty ? job.sellerId : 'Unknown Seller');
                    final initial = sellerName.isNotEmpty ? sellerName[0].toUpperCase() : '?';

                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: _purple.withValues(alpha: 0.1),
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: _purple,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sellerName,
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${job.deliveryStops.length} stops',
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
