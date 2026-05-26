import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/carpool_request_model.dart';
import 'ride_status_badge.dart';

class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.request, required this.onTap});

  final CarpoolRequestModel request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request.originLabel,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  RideStatusBadge(status: request.status),
                ],
              ),
              const SizedBox(height: 8),
              Text('To ${request.destinationLabel}', style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 8),
              Text(
                DateFormat('EEE, d MMM • h:mm a').format(request.scheduledAt),
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Text('${request.availableSeats} / ${request.totalSeats} seats left'),
            ],
          ),
        ),
      ),
    );
  }
}