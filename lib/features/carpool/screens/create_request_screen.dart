import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:unipool/core/constants.dart';
import '../models/carpool_request_model.dart';
import '../providers/carpool_provider.dart';
import 'pick_location_screen.dart';

class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _originLabelController = TextEditingController();
  final _destinationLabelController = TextEditingController();
  final _seatsController = TextEditingController(text: '3');
  final _totalAmountController = TextEditingController();
  DateTime? _scheduledAt;
  double? _originLat;
  double? _originLng;
  double? _destinationLat;
  double? _destinationLng;
  String _rideType = CarpoolRideTypes.studentDriver;
  bool _allowUnverifiedDriver = false;
  String? _qrCodeUrl;
  bool _saving = false;

  @override
  void dispose() {
    _originLabelController.dispose();
    _destinationLabelController.dispose();
    _seatsController.dispose();
    _totalAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation({required bool isOrigin}) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => PickLocationScreen(
          title: isOrigin ? 'Pick origin' : 'Pick destination',
          initialLabel: isOrigin ? _originLabelController.text : _destinationLabelController.text,
          initialLat: isOrigin ? _originLat : _destinationLat,
          initialLng: isOrigin ? _originLng : _destinationLng,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      if (isOrigin) {
        _originLabelController.text = result['label'] as String? ?? '';
        _originLat = result['lat'] as double?;
        _originLng = result['lng'] as double?;
      } else {
        _destinationLabelController.text = result['label'] as String? ?? '';
        _destinationLat = result['lat'] as double?;
        _destinationLng = result['lng'] as double?;
      }
    });
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: DateTime.now());
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _uploadQrCode() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final storageRef = FirebaseStorage.instance.ref().child('user_qr_codes/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await storageRef.putFile(file);
    final downloadUrl = await storageRef.getDownloadURL();

    await FirebaseFirestore.instance.collection(AppCollections.users).doc(uid).update({
      AppFields.userQrCodeUrlSnake: downloadUrl,
    });

    setState(() => _qrCodeUrl = downloadUrl);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_scheduledAt == null || _originLat == null || _originLng == null || _destinationLat == null || _destinationLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete the location and time fields.')));
      return;
    }

    final request = CarpoolRequestModel(
      id: '',
      creatorId: FirebaseAuth.instance.currentUser!.uid,
      originLabel: _originLabelController.text.trim(),
      originLat: _originLat!,
      originLng: _originLng!,
      destinationLabel: _destinationLabelController.text.trim(),
      destinationLat: _destinationLat!,
      destinationLng: _destinationLng!,
      scheduledAt: _scheduledAt!,
      totalSeats: int.tryParse(_seatsController.text.trim()) ?? 3,
      availableSeats: int.tryParse(_seatsController.text.trim()) ?? 3,
      rideType: _rideType,
      allowUnverifiedDriver: _allowUnverifiedDriver,
      status: CarpoolRequestStatuses.open,
      createdAt: DateTime.now(),
    );

    setState(() => _saving = true);
    try {
      await context.read<CarpoolProvider>().createRequest(request);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Carpool Request')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _LocationTile(title: 'Origin', value: _originLabelController.text.isEmpty ? 'Set origin' : _originLabelController.text, onTap: () => _pickLocation(isOrigin: true)),
            const SizedBox(height: 12),
            _LocationTile(title: 'Destination', value: _destinationLabelController.text.isEmpty ? 'Set destination' : _destinationLabelController.text, onTap: () => _pickLocation(isOrigin: false)),
            const SizedBox(height: 12),
            ListTile(title: const Text('Date and time'), subtitle: Text(_scheduledAt == null ? 'Select schedule' : DateFormat('EEE, d MMM • h:mm a').format(_scheduledAt!)), trailing: const Icon(Icons.event), onTap: _pickDateTime),
            const SizedBox(height: 12),
            TextFormField(controller: _seatsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total seats'), validator: (value) => (value == null || value.isEmpty) ? 'Enter total seats' : null),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: CarpoolRideTypes.studentDriver, label: Text('Student Driver')),
                ButtonSegment(value: CarpoolRideTypes.grab, label: Text('Grab')),
              ],
              selected: {_rideType},
              onSelectionChanged: (value) => setState(() => _rideType = value.first),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _allowUnverifiedDriver,
              onChanged: (value) => setState(() => _allowUnverifiedDriver = value),
              title: const Text('Allow unverified drivers'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _totalAmountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Total fare (optional)'),
            ),
            const SizedBox(height: 16),
            Text('QR Code', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_qrCodeUrl != null)
              Image.network(_qrCodeUrl!, height: 120)
            else
              OutlinedButton.icon(onPressed: _uploadQrCode, icon: const Icon(Icons.upload), label: const Text('Upload QR')),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create Request'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({required this.title, required this.value, required this.onTap});

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFD9E2EC))),
      title: Text(title),
      subtitle: Text(value),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}