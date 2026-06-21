// Hallmark · pre-emit critique: P4 H5 E5 S4 R4 V4
// Screen: Delivery Job Detail (Driver apply view + Seller manage view)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:unipool/core/constants.dart';
import '../models/delivery_application_model.dart';
import '../models/delivery_job_model.dart';
import '../providers/delivery_provider.dart';
import 'delivery_chat_screen.dart';
import '../services/delivery_service.dart';
import '../services/delivery_proof_service.dart';
import '../providers/delivery_proof_provider.dart';
import '../models/delivery_proof_model.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kPurple = Color(0xFF7C3AED);
const _kPurpleLight = Color(0xFFF3EEFF);
const _kGreenBg = Color(0xFFECFBF3);
const _kGreen = Color(0xFF16A34A);
const _kSurface = Color(0xFFF8F8F8);
const _kCardBg = Colors.white;
const _kTextPrimary = Color(0xFF111827);
const _kTextSecondary = Color(0xFF6B7280);
const _kDivider = Color(0xFFE5E7EB);

class DeliveryJobDetailScreen extends StatefulWidget {
  const DeliveryJobDetailScreen({
    super.key,
    required this.job,
    required this.currentUid,
  });

  final DeliveryJobModel job;
  final String currentUid;

  @override
  State<DeliveryJobDetailScreen> createState() =>
      _DeliveryJobDetailScreenState();
}

class _DeliveryJobDetailScreenState extends State<DeliveryJobDetailScreen> {
  bool _applying = false;
  bool _justApplied = false;

  bool get _isSeller => widget.job.sellerId == widget.currentUid;

  Future<void> _applyToJob() async {
    setState(() => _applying = true);
    try {
      await context.read<DeliveryProvider>().applyToJob(
            widget.job.id,
            widget.currentUid,
          );
      if (mounted) setState(() => _justApplied = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DeliveryJobModel>(
      stream: DeliveryService().getJobById(widget.job.id),
      initialData: widget.job,
      builder: (context, snapshot) {
        final job = snapshot.data ?? widget.job;
        final stops = job.deliveryStops;
        final stopLabels = stops
            .map((s) => (s['label'] as String?) ?? '')
            .where((l) => l.isNotEmpty)
            .join(' • ');
        final timeText =
            '${DateFormat('h:mm a').format(job.timeWindowStart)} – '
            '${DateFormat('h:mm a').format(job.timeWindowEnd)}';
        final sellerInitials = _initials(job.sellerId);
        final provider = context.watch<DeliveryProvider>();

        return Scaffold(
          backgroundColor: _kSurface,
          appBar: AppBar(
            backgroundColor: _kPurple,
            foregroundColor: Colors.white,
            title: const Text(
              'Delivery Details',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            elevation: 0,
            actions: [
              if (_isSeller)
                IconButton(
                  icon: const Icon(Icons.people_outline),
                  tooltip: 'Applicants',
                  onPressed: () => _showApplicantsSheet(context, provider),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            children: [
              // ── Main Info Card ──
              Container(
                decoration: BoxDecoration(
                  color: _kCardBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + price
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _kPurpleLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.inventory_2_outlined,
                              color: _kPurple, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${job.title} (${job.quantity} ${job.quantity == 1 ? 'item' : 'items'})',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: _kTextPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PriceBadge(price: job.price),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (job.items.isNotEmpty && job.items.first['photo_url'] != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          job.items.first['photo_url'] as String,
                          width: double.infinity,
                          height: 180,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Route timeline
                    _RouteTimeline(
                      pickupLabel: job.pickupLabel,
                      stopLabels: stopLabels,
                    ),
                    const SizedBox(height: 14),

                    // Time window
                    Row(
                      children: [
                        const Icon(Icons.access_time_outlined,
                            size: 16, color: _kTextSecondary),
                        const SizedBox(width: 8),
                        Text(
                          timeText,
                          style: const TextStyle(
                            fontSize: 13,
                            color: _kTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: _kDivider, height: 1),
                    const SizedBox(height: 16),

                    // Seller info
                    _SellerRow(uid: job.sellerId, initials: sellerInitials),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Status Badge (if not open) ──
              if (job.jobStatus != DeliveryJobStatuses.open)
                _StatusCard(status: job.jobStatus),

              // ── Seller view: Proof review card ──
              if (_isSeller && job.jobStatus == DeliveryJobStatuses.proofPending) ...[
                const SizedBox(height: 16),
                StreamBuilder<List<DeliveryProofModel>>(
                  stream: DeliveryProofService().getProofs(job.id),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: _kPurple));
                    }
                    final proofs = snap.data ?? [];
                    if (proofs.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final proof = proofs.first; // Get latest proof

                    return Container(
                      decoration: BoxDecoration(
                        color: _kCardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _kDivider),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.assignment_turned_in_outlined, color: _kPurple, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Submitted Proof',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _kTextPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (proof.notes.isNotEmpty) ...[
                            const Text(
                              'Driver Notes:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _kTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              proof.notes,
                              style: const TextStyle(
                                fontSize: 14,
                                color: _kTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (proof.photoUrls.isNotEmpty) ...[
                            const Text(
                              'Submitted Photo:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _kTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...proof.photoUrls.map((url) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  url,
                                  width: MediaQuery.of(context).size.width / 3,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            )),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(color: Colors.redAccent),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final proofProvider = context.read<DeliveryProofProvider>();
                                    final deliveryProvider = context.read<DeliveryProvider>();
                                    final confirm = await _showConfirmReview(context, false);
                                    if (confirm == true) {
                                      await proofProvider.reviewProof(
                                        job.id,
                                        proof.id,
                                        status: DeliveryProofStatuses.rejected,
                                        reviewerId: widget.currentUid,
                                      );
                                      // Revert job status back to inProgress
                                      await deliveryProvider.updateJobStatus(
                                        job.id,
                                        DeliveryJobStatuses.inProgress,
                                      );
                                    }
                                  },
                                  child: const Text('Reject Proof'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _kGreen,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final proofProvider = context.read<DeliveryProofProvider>();
                                    final confirm = await _showConfirmReview(context, true);
                                    if (confirm == true) {
                                      await proofProvider.reviewProof(
                                        job.id,
                                        proof.id,
                                        status: DeliveryProofStatuses.approved,
                                        reviewerId: widget.currentUid,
                                      );
                                    }
                                  },
                                  child: const Text('Approve Proof'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],

              // ── Seller view: Mark completed button ──
              if (_isSeller && job.jobStatus == DeliveryJobStatuses.awaitingPayment) ...[
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: _kCardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kDivider),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Awaiting Payment',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _kTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'The proof was approved. Once you have settled payment with the driver, please mark the job as completed.',
                        style: TextStyle(
                          fontSize: 13,
                          color: _kTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _kPurple,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () async {
                            final deliveryProvider = context.read<DeliveryProvider>();
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                title: const Text('Complete Job'),
                                content: const Text(
                                    'Are you sure you want to mark this job as completed?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: TextButton.styleFrom(
                                      foregroundColor: _kPurple,
                                    ),
                                    child: const Text('Complete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await deliveryProvider.completeJob(job.id);
                            }
                          },
                          child: const Text('Mark as Completed'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Seller: view applicants in-line summary ──
              if (_isSeller) ...[
                const SizedBox(height: 16),
                _SellerActionsCard(
                  job: job,
                  provider: provider,
                  onViewApplicants: () =>
                      _showApplicantsSheet(context, provider),
                ),
              ],

              // ── If seller: Chat with assigned driver ──
              if (_isSeller && job.assignedDriverId.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ChatTile(
                  label: 'Chat with Driver',
                  icon: Icons.chat_bubble_outline,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DeliveryChatScreen(
                        jobId: job.id,
                        currentUid: widget.currentUid,
                        otherUid: job.assignedDriverId,
                        otherLabel: 'Driver',
                      ),
                    ),
                  ),
                ),
              ],

              // ── If driver: Chat with seller ──
              if (!_isSeller && job.assignedDriverId == widget.currentUid) ...[
                const SizedBox(height: 12),
                _ChatTile(
                  label: 'Chat with Seller',
                  icon: Icons.chat_bubble_outline,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DeliveryChatScreen(
                        jobId: job.id,
                        currentUid: widget.currentUid,
                        otherUid: job.sellerId,
                        otherLabel: 'Seller',
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),

          // ── Bottom CTA ──
          bottomNavigationBar: _isSeller
              ? const SizedBox.shrink()
              : (job.assignedDriverId == widget.currentUid)
                  ? _buildAssignedDriverCTA(context, job)
                  : Container(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        12,
                        16,
                        16 + MediaQuery.of(context).padding.bottom,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(15),
                            blurRadius: 16,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: StreamBuilder<DeliveryApplicationModel?>(
                        stream: _myApplicationStream(),
                        builder: (context, snap) {
                          final myApp = snap.data;
                          final alreadyApplied =
                              myApp != null || _justApplied;
                          final status = myApp?.status ?? '';

                          String label;
                          Color btnColor;
                          bool enabled;

                          final effectiveStatus = _justApplied ? DeliveryApplicationStatuses.pending : status;

                          if (effectiveStatus == DeliveryApplicationStatuses.approved) {
                            label = '✓ Application Accepted';
                            btnColor = _kGreen;
                            enabled = false;
                          } else if (effectiveStatus == DeliveryApplicationStatuses.rejected) {
                            label = 'Application Rejected. Apply Again?';
                            btnColor = Colors.redAccent;
                            enabled = true;
                          } else if (alreadyApplied && effectiveStatus == DeliveryApplicationStatuses.pending) {
                            label = 'Application Submitted';
                            btnColor = _kTextSecondary;
                            enabled = false;
                          } else if (job.jobStatus != DeliveryJobStatuses.open) {
                            label = 'Job No Longer Available';
                            btnColor = _kTextSecondary;
                            enabled = false;
                          } else {
                            label = 'Apply for This Job';
                            btnColor = _kPurple;
                            enabled = true;
                          }

                          return SizedBox(
                            height: 52,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: btnColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: (enabled && !_applying) ? _applyToJob : null,
                              child: _applying
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      label,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
        );
      },
    );
  }

  Stream<DeliveryApplicationModel?> _myApplicationStream() {
    return FirebaseFirestore.instance
        .collection(AppCollections.deliveryJobs)
        .doc(widget.job.id)
        .collection('applications')
        .where('driver_id', isEqualTo: widget.currentUid)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return DeliveryApplicationModel.fromMap(doc.data(), doc.id);
    });
  }

  Future<bool?> _showConfirmReview(BuildContext context, bool approve) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(approve ? 'Approve Proof' : 'Reject Proof'),
        content: Text(approve
            ? 'Are you sure you want to approve this proof? This will move the job status to Awaiting Payment.'
            : 'Are you sure you want to reject this proof? This will revert the job status to In Progress so the driver can resubmit.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: approve ? _kGreen : Colors.redAccent,
            ),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedDriverCTA(BuildContext context, DeliveryJobModel job) {
    String label;
    Color btnColor;
    bool enabled;
    VoidCallback? onPressed;

    switch (job.jobStatus) {
      case DeliveryJobStatuses.driverAssigned:
        label = 'Start Delivery';
        btnColor = _kPurple;
        enabled = true;
        onPressed = () async {
          final deliveryProvider = context.read<DeliveryProvider>();
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Start Delivery'),
              content: const Text('Are you sure you want to start this delivery?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: _kPurple),
                  child: const Text('Start'),
                ),
              ],
            ),
          );
          if (confirm == true) {
            await deliveryProvider.startDelivery(job.id);
          }
        };
        break;
      case DeliveryJobStatuses.inProgress:
        label = 'Submit Proof';
        btnColor = _kPurple;
        enabled = true;
        onPressed = () => _showSubmitProofDialog(context, job.id);
        break;
      case DeliveryJobStatuses.proofPending:
        label = 'Proof Pending Seller Review';
        btnColor = const Color(0xFFF59E0B);
        enabled = false;
        break;
      case DeliveryJobStatuses.awaitingPayment:
        label = 'Awaiting Payment';
        btnColor = const Color(0xFFF59E0B);
        enabled = false;
        break;
      case DeliveryJobStatuses.completed:
        label = '✓ Delivery Completed';
        btnColor = _kGreen;
        enabled = false;
        break;
      case DeliveryJobStatuses.cancelled:
        label = 'Job Cancelled';
        btnColor = Colors.redAccent;
        enabled = false;
        break;
      default:
        label = 'Assigned to You';
        btnColor = _kTextSecondary;
        enabled = false;
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        height: 52,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: btnColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: enabled ? onPressed : null,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  void _showSubmitProofDialog(BuildContext context, String jobId) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SubmitProofDialog(
        jobId: jobId,
        currentUid: widget.currentUid,
      ),
    );
  }

  void _showApplicantsSheet(
      BuildContext context, DeliveryProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ApplicantsSheet(
        jobId: widget.job.id,
        currentUid: widget.currentUid,
      ),
    );
  }

  String _initials(String uid) {
    if (uid.isEmpty) return '?';
    return uid.substring(0, 1).toUpperCase();
  }
}

// ─── Submit Proof Dialog ──────────────────────────────────────────────────────

class _SubmitProofDialog extends StatefulWidget {
  const _SubmitProofDialog({
    required this.jobId,
    required this.currentUid,
  });

  final String jobId;
  final String currentUid;

  @override
  State<_SubmitProofDialog> createState() => _SubmitProofDialogState();
}

class _SubmitProofDialogState extends State<_SubmitProofDialog> {
  final _notesController = TextEditingController();
  XFile? _pickedFile;
  bool _isSubmitting = false;

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() {
        _pickedFile = picked;
      });
    }
  }

  Future<void> _uploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _pickedFile = picked;
      });
    }
  }

  Future<void> _submit() async {
    final notes = _notesController.text.trim();
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please take or upload a photo for proof.')),
      );
      return;
    }
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter notes.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final provider = context.read<DeliveryProofProvider>();

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('delivery_proofs')
          .child(widget.jobId)
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      if (kIsWeb) {
        final bytes = await _pickedFile!.readAsBytes();
        await storageRef.putData(bytes);
      } else {
        await storageRef.putFile(File(_pickedFile!.path));
      }
      final photoUrl = await storageRef.getDownloadURL();

      final proof = DeliveryProofModel(
        id: '',
        driverId: widget.currentUid,
        stopIndex: null,
        photoUrls: [photoUrl],
        notes: notes,
        status: DeliveryProofStatuses.submitted,
        reviewedBy: '',
        reviewedAt: null,
        createdAt: DateTime.now(),
      );

      await provider.submitProof(widget.jobId, proof);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proof submitted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit proof: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Submit Delivery Proof'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes (e.g., Left at reception)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            enabled: !_isSubmitting,
          ),
          const SizedBox(height: 16),
          if (_pickedFile != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: kIsWeb
                  ? Container(
                      height: 120,
                      width: double.infinity,
                      color: _kPurple.withAlpha(20),
                      child: const Center(
                        child: Icon(Icons.check_circle, color: _kPurple, size: 48),
                      ),
                    )
                  : Image.file(
                      File(_pickedFile!.path),
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              if (!kIsWeb) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: const Text('Camera'),
                    onPressed: _isSubmitting ? null : _takePhoto,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: const Text(kIsWeb ? 'Choose Image' : 'Gallery'),
                  onPressed: _isSubmitting ? null : _uploadPhoto,
                ),
              ),
            ],
          ),
          if (_pickedFile == null)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Photo is required',
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isSubmitting ? null : _submit,
          style: TextButton.styleFrom(foregroundColor: _kPurple),
          child: _isSubmitting 
              ? const SizedBox(
                  width: 16, height: 16, 
                  child: CircularProgressIndicator(strokeWidth: 2, color: _kPurple)
                ) 
              : const Text('Submit'),
        ),
      ],
    );
  }
}

// ─── Route Timeline ───────────────────────────────────────────────────────────

class _RouteTimeline extends StatelessWidget {
  const _RouteTimeline({
    required this.pickupLabel,
    required this.stopLabels,
  });

  final String pickupLabel;
  final String stopLabels;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline dots + line
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: _kPurple,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  color: const Color(0xFFDDD6FE),
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: _kPurple,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Labels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pickup',
                      style: TextStyle(
                        fontSize: 11,
                        color: _kTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      pickupLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _kTextPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery Stops',
                      style: TextStyle(
                        fontSize: 11,
                        color: _kTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      stopLabels.isEmpty ? 'No stops specified' : stopLabels,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _kTextPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Seller Row ───────────────────────────────────────────────────────────────

class _SellerRow extends StatelessWidget {
  const _SellerRow({required this.uid, required this.initials});

  final String uid;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection(AppCollections.users)
          .doc(uid)
          .get(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? const <String, dynamic>{};
        final name = (data[AppFields.userFullName] as String?)?.trim() ?? uid;
        final init = name.isNotEmpty ? _initials(name) : initials;

        return Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _kPurpleLight,
              child: Text(
                init,
                style: const TextStyle(
                  color: _kPurple,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kTextPrimary,
                  ),
                ),
                const Text(
                  'Seller',
                  style: TextStyle(fontSize: 12, color: _kTextSecondary),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }
}

// ─── Price Badge ──────────────────────────────────────────────────────────────

class _PriceBadge extends StatelessWidget {
  const _PriceBadge({required this.price});
  final double price;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _kGreenBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'RM${price.toStringAsFixed(0)}',
        style: const TextStyle(
          color: _kGreen,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

// ─── Status Card ──────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final label = _labelFor(status);
    final color = _colorFor(status);

    return Container(
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(_iconFor(status), color: color, size: 20),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _labelFor(String status) => switch (status) {
        DeliveryJobStatuses.open => 'Open for Applications',
        DeliveryJobStatuses.driverAssigned => 'Driver Assigned',
        DeliveryJobStatuses.inProgress => 'In Progress',
        DeliveryJobStatuses.completed => 'Completed',
        DeliveryJobStatuses.cancelled => 'Cancelled',
        DeliveryJobStatuses.proofPending => 'Proof Pending',
        DeliveryJobStatuses.awaitingPayment => 'Awaiting Payment',
        DeliveryJobStatuses.disputed => 'Under Dispute',
        _ => status,
      };

  Color _colorFor(String status) => switch (status) {
        DeliveryJobStatuses.inProgress => const Color(0xFF0EA5E9),
        DeliveryJobStatuses.completed => _kGreen,
        DeliveryJobStatuses.cancelled => Colors.redAccent,
        DeliveryJobStatuses.disputed => Colors.orange,
        _ => _kPurple,
      };

  IconData _iconFor(String status) => switch (status) {
        DeliveryJobStatuses.inProgress => Icons.directions_run,
        DeliveryJobStatuses.completed => Icons.check_circle_outline,
        DeliveryJobStatuses.cancelled => Icons.cancel_outlined,
        DeliveryJobStatuses.disputed => Icons.warning_amber_outlined,
        _ => Icons.info_outline,
      };
}

// ─── Seller Actions Card ──────────────────────────────────────────────────────

class _SellerActionsCard extends StatelessWidget {
  const _SellerActionsCard({
    required this.job,
    required this.provider,
    required this.onViewApplicants,
  });

  final DeliveryJobModel job;
  final DeliveryProvider provider;
  final VoidCallback onViewApplicants;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kDivider),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _kPurpleLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.people_alt_outlined,
                  size: 18, color: _kPurple),
            ),
            title: const Text(
              'View Applicants',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: const Text(
              'Accept or reject drivers',
              style: TextStyle(fontSize: 12, color: _kTextSecondary),
            ),
            trailing:
                const Icon(Icons.chevron_right, color: _kTextSecondary),
            onTap: onViewApplicants,
          ),
          if (job.jobStatus == DeliveryJobStatuses.open) ...[
            const Divider(height: 1, color: _kDivider),
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.cancel_outlined,
                    size: 18, color: Colors.redAccent),
              ),
              title: const Text(
                'Cancel Job',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.redAccent),
              ),
              trailing:
                  const Icon(Icons.chevron_right, color: _kTextSecondary),
              onTap: provider.isLoading
                  ? null
                  : () async {
                      final deliveryProvider = context.read<DeliveryProvider>();
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          title: const Text('Cancel Job'),
                          content: const Text(
                              'Are you sure you want to cancel this job?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Back'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.redAccent),
                              child: const Text('Cancel Job'),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                      await deliveryProvider.updateJobStatus(
                            job.id,
                            DeliveryJobStatuses.cancelled,
                          );
                      if (context.mounted) Navigator.pop(context);
                    },
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Chat Tile ────────────────────────────────────────────────────────────────

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kDivider),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _kPurpleLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: _kPurple),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _kTextPrimary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: _kTextSecondary),
          ],
        ),
      ),
    );
  }
}

// ─── Applicants Bottom Sheet ──────────────────────────────────────────────────

class _ApplicantsSheet extends StatefulWidget {
  const _ApplicantsSheet({
    required this.jobId,
    required this.currentUid,
  });

  final String jobId;
  final String currentUid;

  @override
  State<_ApplicantsSheet> createState() => _ApplicantsSheetState();
}

class _ApplicantsSheetState extends State<_ApplicantsSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DeliveryProvider>().loadApplications(widget.jobId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryProvider>();

    final allApps = provider.applications;
    final approvedApp = allApps.where((a) => a.status == DeliveryApplicationStatuses.approved).firstOrNull;
    final apps = approvedApp != null ? [approvedApp] : allApps;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              const Text(
                'Applicants',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _kTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${apps.length} ${apps.length == 1 ? 'driver' : 'drivers'} applied',
                style: const TextStyle(
                  fontSize: 13,
                  color: _kTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              if (provider.isLoading && apps.isEmpty)
                const Expanded(
                  child: Center(
                      child: CircularProgressIndicator(color: _kPurple)),
                )
              else if (apps.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'No applicants yet.',
                      style: TextStyle(color: _kTextSecondary),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: apps.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _ApplicantCard(
                      application: apps[i],
                      jobId: widget.jobId,
                      currentUid: widget.currentUid,
                    ),
                  ),
                ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
            ],
          ),
        );
      },
    );
  }
}

// ─── Applicant Card ───────────────────────────────────────────────────────────

class _ApplicantCard extends StatefulWidget {
  const _ApplicantCard({
    required this.application,
    required this.jobId,
    required this.currentUid,
  });

  final DeliveryApplicationModel application;
  final String jobId;
  final String currentUid;

  @override
  State<_ApplicantCard> createState() => _ApplicantCardState();
}

class _ApplicantCardState extends State<_ApplicantCard> {
  late Future<DocumentSnapshot<Map<String, dynamic>>> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = FirebaseFirestore.instance
        .collection(AppCollections.users)
        .doc(widget.application.driverId)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<DeliveryProvider>();
    final isPending =
        widget.application.status == DeliveryApplicationStatuses.pending;
    final isApproved =
        widget.application.status == DeliveryApplicationStatuses.approved;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isApproved
              ? _kGreen.withAlpha(80)
              : _kDivider,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: _userFuture,
                builder: (context, snap) {
                  final data =
                      snap.data?.data() ?? const <String, dynamic>{};
                  final name =
                      (data[AppFields.userFullName] as String?)?.trim() ??
                          widget.application.driverId;
                  final init = _initials(name);
                  final verified =
                      (data[AppFields.userVerificationStatus] as String?) ==
                          'approved';

                  return Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: _kPurpleLight,
                        child: Text(
                          init,
                          style: const TextStyle(
                            color: _kPurple,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _kTextPrimary,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                'Driver',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _kTextSecondary,
                                ),
                              ),
                              if (verified) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified,
                                    size: 13, color: _kPurple),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const Spacer(),
              _StatusPill(status: widget.application.status),
            ],
          ),
          if (widget.application.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '"${widget.application.notes}"',
              style: const TextStyle(
                fontSize: 13,
                color: _kTextSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side:
                          const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: provider.isLoading
                        ? null
                        : () async {
                            try {
                              await provider.rejectApplication(
                                  widget.jobId, widget.application.id);
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.redAccent,
                                  content: Text(e.toString()),
                                ),
                              );
                            }
                          },
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _kPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: provider.isLoading
                        ? null
                        : () async {
                            try {
                              await provider.approveApplication(
                                  widget.jobId, widget.application.id);
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.redAccent,
                                  content: Text(e.toString()),
                                ),
                              );
                            }
                          },
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],

        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }
}

// ─── Status Pill ──────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      DeliveryApplicationStatuses.approved => ('Accepted', _kGreen),
      DeliveryApplicationStatuses.rejected =>
        ('Rejected', Colors.redAccent),
      DeliveryApplicationStatuses.withdrawn =>
        ('Withdrawn', _kTextSecondary),
      _ => ('Pending', const Color(0xFFF59E0B)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
