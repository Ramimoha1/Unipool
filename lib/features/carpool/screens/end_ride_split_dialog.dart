import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/carpool_group_model.dart';
import '../models/carpool_request_model.dart';
import '../providers/payment_provider.dart';
import '../services/payment_service.dart';
import 'payment_screen.dart';

class EndRideSplitDialog extends StatefulWidget {
  const EndRideSplitDialog({
    super.key,
    required this.request,
    required this.group,
    required this.memberNames,
  });

  final CarpoolRequestModel request;
  final CarpoolGroupModel group;
  final Map<String, String> memberNames;

  @override
  State<EndRideSplitDialog> createState() => _EndRideSplitDialogState();
}

class _EndRideSplitDialogState extends State<EndRideSplitDialog> {
  late TextEditingController _totalFareController;
  String _splitType = 'equally_without_me'; // 'equally_without_me', 'equally', 'manual'
  final Map<String, TextEditingController> _manualDuesControllers = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _totalFareController = TextEditingController(
      text: widget.request.fare?.toStringAsFixed(2) ?? '',
    );
    for (final uid in widget.group.memberIds) {
      _manualDuesControllers[uid] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _totalFareController.dispose();
    for (final controller in _manualDuesControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, double> _calculateDues() {
    final total = double.tryParse(_totalFareController.text.trim()) ?? 0.0;
    final dues = <String, double>{};
    final memberIds = widget.group.memberIds;
    final currentUserId = widget.request.creatorId; // Using creator as default skip, or driver

    if (_splitType == 'manual') {
      for (final uid in memberIds) {
        dues[uid] = double.tryParse(_manualDuesControllers[uid]?.text.trim() ?? '') ?? 0.0;
      }
    } else if (_splitType == 'equally') {
      if (memberIds.isEmpty) return dues;
      final split = total / memberIds.length;
      for (final uid in memberIds) {
        dues[uid] = split;
      }
    } else {
      // equally_without_me
      final driverId = widget.group.driverId.isNotEmpty ? widget.group.driverId : widget.request.creatorId;
      final payingMembers = memberIds.where((id) => id != driverId).toList();
      if (payingMembers.isEmpty) {
        for (final uid in memberIds) dues[uid] = 0.0;
      } else {
        final split = total / payingMembers.length;
        for (final uid in memberIds) {
          dues[uid] = payingMembers.contains(uid) ? split : 0.0;
        }
      }
    }
    return dues;
  }

  Future<void> _submit() async {
    final total = double.tryParse(_totalFareController.text.trim());
    if (total == null || total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid total fare')),
      );
      return;
    }

    final dues = _calculateDues();
    final paymentService = PaymentService();
    
    setState(() => _saving = true);
    try {
      final payment = await paymentService.getPayment(widget.request.id);
      if (payment == null) {
        throw Exception('Payment has not been initialized for this request.');
      }
      
      await context.read<PaymentProvider>().triggerPayment(
        payment.id,
        widget.request.id,
        total,
        dues,
      );

      if (mounted) {
        Navigator.pop(context, true); // Return true on success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('End Ride & Split Fare'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _totalFareController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Total Fare (RM)'),
            ),
            const SizedBox(height: 16),
            const Text('Split Options', style: TextStyle(fontWeight: FontWeight.bold)),
            RadioListTile<String>(
              title: const Text('Equally without me'),
              value: 'equally_without_me',
              groupValue: _splitType,
              onChanged: (val) => setState(() => _splitType = val!),
            ),
            RadioListTile<String>(
              title: const Text('Equally (everyone pays)'),
              value: 'equally',
              groupValue: _splitType,
              onChanged: (val) => setState(() => _splitType = val!),
            ),
            RadioListTile<String>(
              title: const Text('Manual'),
              value: 'manual',
              groupValue: _splitType,
              onChanged: (val) => setState(() => _splitType = val!),
            ),
            if (_splitType == 'manual') ...[
              const Divider(),
              const Text('Manual Split (RM)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...widget.group.memberIds.map((uid) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _manualDuesControllers[uid],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: widget.memberNames[uid] ?? uid,
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Confirm & End Ride'),
        ),
      ],
    );
  }
}
