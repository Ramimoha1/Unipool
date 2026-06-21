// Screen: File a Delivery Dispute (Seller -> Driver or Driver -> Seller)

import 'package:flutter/material.dart';
import 'package:unipool/core/constants.dart';
import '../models/delivery_dispute_model.dart';
import '../models/delivery_job_model.dart';
import '../services/delivery_dispute_service.dart';

// ─── Design tokens (matches delivery_job_detail_screen.dart) ──────────────
const _kPurple = Color(0xFF7C3AED);
const _kPurpleLight = Color(0xFFF3EEFF);
const _kSurface = Color(0xFFF8F8F8);
const _kCardBg = Colors.white;
const _kTextPrimary = Color(0xFF111827);
const _kTextSecondary = Color(0xFF6B7280);
const _kDivider = Color(0xFFE5E7EB);
const _kRed = Color(0xFFDC2626);
const _kRedBg = Color(0xFFFEF2F2);

class DeliveryDisputeScreen extends StatefulWidget {
  const DeliveryDisputeScreen({
    super.key,
    required this.job,
    required this.currentUid,
  });

  final DeliveryJobModel job;
  final String currentUid;

  @override
  State<DeliveryDisputeScreen> createState() => _DeliveryDisputeScreenState();
}

class _DeliveryDisputeScreenState extends State<DeliveryDisputeScreen> {
  final _disputeService = DeliveryDisputeService();
  final _descriptionController = TextEditingController();

  String? _selectedReason;
  bool _submitting = false;

  bool get _isSeller => widget.job.sellerId == widget.currentUid;

  // Reason list depends on which side of the job is filing.
  Map<String, String> get _reasonOptions => _isSeller
      ? DeliveryDisputeSellerReasons.labels
      : DeliveryDisputeDriverReasons.labels;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reason.')),
      );
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe what happened.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final dispute = DeliveryDisputeModel(
        id: '',
        jobId: widget.job.id,
        sellerId: widget.job.sellerId,
        driverId: widget.job.assignedDriverId,
        filedBy: widget.currentUid,
        reason: _selectedReason!,
        description: _descriptionController.text.trim(),
        evidenceUrls: const [],
        status: DeliveryDisputeStatuses.open,
        reviewedBy: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _disputeService.createDispute(dispute);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: _kPurple,
          content: Text(
            'Dispute filed. The job is paused until an admin reviews it.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(error.toString()),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        backgroundColor: _kCardBg,
        elevation: 0,
        foregroundColor: _kTextPrimary,
        title: const Text(
          'Report an Issue',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kRedBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kRed.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: _kRed, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Filing a report will pause this job — neither '
                        'payment nor marking it complete can happen until '
                        'an admin reviews it. Chat and proof submission '
                        'stay open.',
                        style: TextStyle(
                          fontSize: 13,
                          color: _kRed.withOpacity(0.9),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.job.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _kTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isSeller
                    ? 'Reporting an issue with the assigned driver'
                    : 'Reporting an issue with the seller',
                style: const TextStyle(fontSize: 13, color: _kTextSecondary),
              ),
              const SizedBox(height: 24),
              const Text(
                'What happened?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kTextPrimary,
                ),
              ),
              const SizedBox(height: 10),
              ..._reasonOptions.entries.map((entry) {
                final selected = _selectedReason == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => setState(() => _selectedReason = entry.key),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? _kPurpleLight : _kCardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? _kPurple : _kDivider,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            size: 20,
                            color: selected ? _kPurple : _kTextSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: TextStyle(
                                fontSize: 14,
                                color: selected ? _kPurple : _kTextPrimary,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              const Text(
                'Describe what happened',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kTextPrimary,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descriptionController,
                maxLines: 5,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText:
                      'Give as much detail as you can — this is what the '
                      'admin will see when reviewing your report.',
                  filled: true,
                  fillColor: _kCardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kDivider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kDivider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kPurple),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _kRed,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Submit Report',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
