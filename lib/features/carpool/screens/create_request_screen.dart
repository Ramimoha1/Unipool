import 'dart:io' as io;

import 'package:flutter/foundation.dart';
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
import '../providers/payment_provider.dart';
import '../../profile/data/bank_details_repository.dart';
import 'pick_location_screen.dart';
import 'request_detail_screen.dart';

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
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();
  DateTime? _scheduledAt;
  double? _originLat;
  double? _originLng;
  double? _destinationLat;
  double? _destinationLng;
  String _rideType = CarpoolRideTypes.studentDriver;
  String _joinMode = CarpoolJoinModes.approval;
  bool _allowUnverifiedDriver = false;
  bool _isCreatorDriver = false;
  String? _qrCodeUrl;
  bool _saving = false;

  @override
  void dispose() {
    _originLabelController.dispose();
    _destinationLabelController.dispose();
    _seatsController.dispose();
    _totalAmountController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final details = await BankDetailsRepository().getBankDetails(uid);
      if (details != null && details.isNotEmpty) {
        setState(() {
          _bankNameController.text = details.bankName;
          _accountNumberController.text = details.accountNumber;
          _accountNameController.text = details.accountHolderName;
          _qrCodeUrl = details.qrCodeUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment profile loaded')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No payment profile found. Configure it in settings.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    }
  }

  Future<void> _pickLocation({required bool isOrigin}) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => PickLocationScreen(
          title: isOrigin ? 'Pick origin' : 'Pick destination',
          initialLabel: isOrigin
              ? _originLabelController.text
              : _destinationLabelController.text,
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
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: DateTime.now(),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _uploadQrCode() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final storageRef = FirebaseStorage.instance.ref().child(
      'user_qr_codes/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      await storageRef.putData(bytes);
    } else {
      final file = io.File(picked.path);
      await storageRef.putFile(file);
    }
    final downloadUrl = await storageRef.getDownloadURL();

    await FirebaseFirestore.instance
        .collection(AppCollections.users)
        .doc(uid)
        .update({AppFields.userQrCodeUrlSnake: downloadUrl});

    setState(() => _qrCodeUrl = downloadUrl);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_scheduledAt == null ||
        _originLat == null ||
        _originLng == null ||
        _destinationLat == null ||
        _destinationLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete the location and time fields.'),
        ),
      );
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
      joinMode: _joinMode,
      allowUnverifiedDriver: _allowUnverifiedDriver,
      status: CarpoolRequestStatuses.open,
      createdAt: DateTime.now(),
      fare: double.tryParse(_totalAmountController.text.trim()),
    );

    setState(() => _saving = true);
    try {
      final createdId = await context.read<CarpoolProvider>().createRequest(
        request,
        isCreatorDriver: _rideType == CarpoolRideTypes.studentDriver && _isCreatorDriver,
      );
      if (createdId != null) {
        if (_rideType == CarpoolRideTypes.grab || (_rideType == CarpoolRideTypes.studentDriver && _isCreatorDriver)) {
          await context.read<PaymentProvider>().initializePayment(
            createdId,
            request.creatorId,
            _qrCodeUrl ?? '',
            _bankNameController.text.trim(),
            _accountNumberController.text.trim(),
            _accountNameController.text.trim(),
          );
        }
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RequestDetailScreen(requestId: createdId),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CarpoolProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Create Carpool Request')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _LocationTile(
              title: 'Origin',
              value: _originLabelController.text.isEmpty
                  ? 'Set origin'
                  : _originLabelController.text,
              onTap: () => _pickLocation(isOrigin: true),
            ),
            const SizedBox(height: 12),
            _LocationTile(
              title: 'Destination',
              value: _destinationLabelController.text.isEmpty
                  ? 'Set destination'
                  : _destinationLabelController.text,
              onTap: () => _pickLocation(isOrigin: false),
            ),
            const SizedBox(height: 12),
            ListTile(
              title: const Text('Date and time'),
              subtitle: Text(
                _scheduledAt == null
                    ? 'Select schedule'
                    : DateFormat('EEE, d MMM • h:mm a').format(_scheduledAt!),
              ),
              trailing: const Icon(Icons.event),
              onTap: _pickDateTime,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _seatsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Total seats'),
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Enter total seats' : null,
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: CarpoolRideTypes.studentDriver,
                  label: Text('Student Driver'),
                ),
                ButtonSegment(
                  value: CarpoolRideTypes.grab,
                  label: Text('Grab'),
                ),
              ],
              selected: {_rideType},
              onSelectionChanged: (value) =>
                  setState(() => _rideType = value.first),
            ),
            if (_rideType == CarpoolRideTypes.studentDriver) ...[
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('I will be the driver for this ride'),
                value: _isCreatorDriver,
                onChanged: (val) => setState(() => _isCreatorDriver = val ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              value: _allowUnverifiedDriver,
              onChanged: (value) =>
                  setState(() => _allowUnverifiedDriver = value),
              title: const Text('Allow unverified drivers'),
            ),
            const SizedBox(height: 12),
            Text(
              'Passenger joining',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: CarpoolJoinModes.open,
                  label: Text('Open Join'),
                ),
                ButtonSegment(
                  value: CarpoolJoinModes.approval,
                  label: Text('Need Approval'),
                ),
              ],
              selected: {_joinMode},
              onSelectionChanged: (value) =>
                  setState(() => _joinMode = value.first),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _totalAmountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Total fare (optional)',
              ),
            ),
            if (_rideType == CarpoolRideTypes.grab || (_rideType == CarpoolRideTypes.studentDriver && _isCreatorDriver)) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Payment Settings', style: Theme.of(context).textTheme.titleMedium),
                  TextButton.icon(
                    onPressed: _loadPaymentProfile,
                    icon: const Icon(Icons.person),
                    label: const Text('Use my profile'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bankNameController,
                decoration: const InputDecoration(labelText: 'Bank Name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _accountNumberController,
                decoration: const InputDecoration(labelText: 'Account Number'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _accountNameController,
                decoration: const InputDecoration(labelText: 'Account Holder Name'),
              ),
              const SizedBox(height: 16),
              Text('QR Code', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              if (_qrCodeUrl != null && _qrCodeUrl!.isNotEmpty)
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Image.network(_qrCodeUrl!, height: 120),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => setState(() => _qrCodeUrl = null),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: _uploadQrCode,
                  icon: const Icon(Icons.upload),
                  label: const Text('Upload QR'),
                ),
            ],
            const SizedBox(height: 20),
            if (provider.hasActiveCarpool)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Card(
                  color: Colors.yellow[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      'You already have an active carpool. Leave it before creating a new request.',
                    ),
                  ),
                ),
              ),
            FilledButton(
              onPressed: (_saving || provider.hasActiveCarpool)
                  ? null
                  : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Request'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.title,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFD9E2EC)),
      ),
      title: Text(title),
      subtitle: Text(value),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
