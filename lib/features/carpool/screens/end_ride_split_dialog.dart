import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/carpool_group_model.dart';
import '../models/carpool_request_model.dart';
import '../providers/payment_provider.dart';
import '../services/payment_service.dart';


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

  Future<void> _submit() async {
    final total = double.tryParse(_totalFareController.text.trim());
    if (total == null || total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid total fare')),
      );
      return;
    }

    final paymentService = PaymentService();
    
    setState(() => _saving = true);
    try {
      double splitAmount = 0.0;
      int numberOfMembers = widget.group.memberIds.length;
      if (_splitType == 'equally_without_me') {
        int passengersCount = numberOfMembers > 1 ? numberOfMembers - 1 : 1;
        splitAmount = total / passengersCount;
      } else {
        // Fallback for 'equally' and 'manual'
        splitAmount = total / numberOfMembers;
      }

      if (!mounted) return;
      await context.read<PaymentProvider>().triggerPayment(
        widget.request.id,
        totalAmount: total,
        splitAmount: splitAmount,
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
              // ignore: deprecated_member_use
              groupValue: _splitType,
              // ignore: deprecated_member_use
              onChanged: (val) => setState(() => _splitType = val!),
            ),
            RadioListTile<String>(
              title: const Text('Equally (everyone pays)'),
              value: 'equally',
              // ignore: deprecated_member_use
              groupValue: _splitType,
              // ignore: deprecated_member_use
              onChanged: (val) => setState(() => _splitType = val!),
            ),
            RadioListTile<String>(
              title: const Text('Manual'),
              value: 'manual',
              // ignore: deprecated_member_use
              groupValue: _splitType,
              // ignore: deprecated_member_use
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
