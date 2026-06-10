// Hallmark · pre-emit critique: P4 H5 E5 S4 R4 V4
// Screen: Post Delivery Job (Seller view)

import 'dart:io' as io;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:unipool/core/constants.dart';
import '../models/delivery_job_model.dart';
import '../providers/delivery_provider.dart';
import 'delivery_job_detail_screen.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kPurple = Color(0xFF7C3AED);
const _kSurface = Color(0xFFF8F8F8);
const _kCardBg = Colors.white;
const _kTextPrimary = Color(0xFF111827);
const _kTextSecondary = Color(0xFF6B7280);
const _kDivider = Color(0xFFE5E7EB);
const _kBorderRadius = 12.0;

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _pickupController = TextEditingController();
  final _itemNameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();

  // Delivery stops — starts with one empty stop
  final List<TextEditingController> _stopControllers = [
    TextEditingController(),
  ];

  TimeOfDay? _windowStart;
  TimeOfDay? _windowEnd;
  String _allowedDrivers = DeliveryAllowedDrivers.verifiedAndUnverified;

  // Photo
  XFile? _itemPhoto;

  bool _saving = false;

  @override
  void dispose() {
    _pickupController.dispose();
    _itemNameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    for (final c in _stopControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _kPurple),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _windowStart = picked;
      } else {
        _windowEnd = picked;
      }
    });
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _itemPhoto = picked);
  }

  Future<String?> _uploadPhoto() async {
    if (_itemPhoto == null) return null;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseStorage.instance.ref().child(
      'delivery_item_photos/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    if (kIsWeb) {
      final bytes = await _itemPhoto!.readAsBytes();
      await ref.putData(bytes);
    } else {
      await ref.putFile(io.File(_itemPhoto!.path));
    }
    return ref.getDownloadURL();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_windowStart == null || _windowEnd == null) {
      _showError('Please select a time window.');
      return;
    }

    final stops = _stopControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .map((label) => {'label': label, 'lat': 0.0, 'lng': 0.0})
        .toList();

    if (stops.isEmpty) {
      _showError('Add at least one delivery stop.');
      return;
    }

    setState(() => _saving = true);

    try {
      String? photoUrl;
      if (_itemPhoto != null) {
        photoUrl = await _uploadPhoto();
      }

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final now = DateTime.now();
      final baseDate = DateTime(now.year, now.month, now.day);
      final start = baseDate.add(
        Duration(hours: _windowStart!.hour, minutes: _windowStart!.minute),
      );
      final end = baseDate.add(
        Duration(hours: _windowEnd!.hour, minutes: _windowEnd!.minute),
      );

      final job = DeliveryJobModel(
        id: '',
        createdBy: uid,
        sellerId: uid,
        title: _itemNameController.text.trim(),
        pickupLabel: _pickupController.text.trim(),
        pickupLat: 0,
        pickupLng: 0,
        deliveryStops: stops,
        deliveryTime: start,
        timeWindowStart: start,
        timeWindowEnd: end,
        items: [
          {
            'name': _itemNameController.text.trim(),
            'description': '',
            if (photoUrl != null) 'photo_url': photoUrl,
          }
        ],
        quantity: int.tryParse(_quantityController.text.trim()) ?? 1,
        price: double.tryParse(_priceController.text.trim()) ?? 0,
        allowedDrivers: _allowedDrivers,
        jobStatus: DeliveryJobStatuses.open,
        assignedDriverId: '',
        sellerApprovedDriverId: '',
        createdAt: now,
        updatedAt: now,
      );

      final id =
          await context.read<DeliveryProvider>().createJob(job);

      if (mounted && id != null) {
        if (!mounted) return;
        final created = job.copyWith(id: id);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DeliveryJobDetailScreen(
              job: created,
              currentUid: uid,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.redAccent,
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        backgroundColor: _kPurple,
        foregroundColor: Colors.white,
        title: const Text(
          'Post Delivery Job',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
          children: [
            // ── Pickup ──
            _SectionLabel(label: 'Pickup Location'),
            const SizedBox(height: 8),
            _StyledField(
              controller: _pickupController,
              hint: 'e.g., NUS Utown',
              prefixIcon: Icons.location_on_outlined,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter pickup location' : null,
            ),
            const SizedBox(height: 20),

            // ── Delivery Stops ──
            _SectionLabel(label: 'Delivery Stops'),
            const SizedBox(height: 8),
            for (int i = 0; i < _stopControllers.length; i++) ...[
              _StyledField(
                controller: _stopControllers[i],
                hint: 'Stop ${i + 1}',
                prefixIcon: Icons.location_on_outlined,
                iconColor: _kTextSecondary,
                validator: i == 0
                    ? (v) => (v == null || v.trim().isEmpty)
                        ? 'Add at least one stop'
                        : null
                    : null,
                suffix: i > 0
                    ? IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.redAccent, size: 20),
                        onPressed: () {
                          setState(() {
                            _stopControllers[i].dispose();
                            _stopControllers.removeAt(i);
                          });
                        },
                      )
                    : null,
              ),
              const SizedBox(height: 8),
            ],
            _AddStopButton(
              onTap: () => setState(
                () => _stopControllers.add(TextEditingController()),
              ),
            ),
            const SizedBox(height: 20),

            // ── Item Name ──
            _SectionLabel(label: 'Item Name'),
            const SizedBox(height: 8),
            _StyledField(
              controller: _itemNameController,
              hint: 'e.g., Textbooks, Food, Groceries',
              prefixIcon: Icons.inventory_2_outlined,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter item name' : null,
            ),
            const SizedBox(height: 20),

            // ── Quantity + Price ──
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel(label: 'Quantity'),
                      const SizedBox(height: 8),
                      _StyledField(
                        controller: _quantityController,
                        hint: '1',
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel(label: 'Pay Offered (\$)'),
                      const SizedBox(height: 8),
                      _StyledField(
                        controller: _priceController,
                        hint: '15',
                        prefixIcon: Icons.attach_money,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Required';
                          }
                          if (double.tryParse(v.trim()) == null) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Time Window ──
            _SectionLabel(label: 'Time Window'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TimePickerTile(
                    value: _windowStart,
                    onTap: () => _pickTime(isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimePickerTile(
                    value: _windowEnd,
                    onTap: () => _pickTime(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Allowed Drivers ──
            _SectionLabel(label: 'Who can deliver?'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(_kBorderRadius),
                border: Border.all(color: _kDivider),
              ),
              child: Column(
                children: [
                  RadioListTile<String>(
                    dense: true,
                    activeColor: _kPurple,
                    title: const Text('Verified drivers only',
                        style: TextStyle(fontSize: 14)),
                    value: DeliveryAllowedDrivers.verifiedOnly,
                    groupValue: _allowedDrivers,
                    onChanged: (v) =>
                        setState(() => _allowedDrivers = v!),
                  ),
                  const Divider(height: 1, color: _kDivider),
                  RadioListTile<String>(
                    dense: true,
                    activeColor: _kPurple,
                    title: const Text('Any driver',
                        style: TextStyle(fontSize: 14)),
                    value: DeliveryAllowedDrivers.verifiedAndUnverified,
                    groupValue: _allowedDrivers,
                    onChanged: (v) =>
                        setState(() => _allowedDrivers = v!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Photo ──
            _SectionLabel(label: 'Item Photo (Optional)'),
            const SizedBox(height: 8),
            _PhotoPicker(
              file: _itemPhoto,
              onTap: _pickPhoto,
            ),
          ],
        ),
      ),

      // ── Bottom CTA ──
      bottomNavigationBar: Container(
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
              backgroundColor: _kPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Post Job',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Reusable sub-widgets ─────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _kTextPrimary,
      ),
    );
  }
}

class _StyledField extends StatelessWidget {
  const _StyledField({
    required this.controller,
    required this.hint,
    this.prefixIcon,
    this.iconColor = _kPurple,
    this.keyboardType,
    this.validator,
    this.suffix,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? prefixIcon;
  final Color iconColor;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: _kTextPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _kTextSecondary, fontSize: 14),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: iconColor, size: 18)
            : null,
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kBorderRadius),
          borderSide: const BorderSide(color: _kDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kBorderRadius),
          borderSide: const BorderSide(color: _kDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kBorderRadius),
          borderSide: const BorderSide(color: _kPurple, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kBorderRadius),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }
}

class _AddStopButton extends StatelessWidget {
  const _AddStopButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_kBorderRadius),
          border: Border.all(
            color: _kPurple.withAlpha(80),
            style: BorderStyle.solid,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: _kPurple, size: 18),
            SizedBox(width: 6),
            Text(
              'Add Another Stop',
              style: TextStyle(
                color: _kPurple,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  const _TimePickerTile({required this.value, required this.onTap});

  final TimeOfDay? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_kBorderRadius),
          border: Border.all(color: _kDivider),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            const Icon(Icons.access_time_outlined,
                size: 18, color: _kTextSecondary),
            const SizedBox(width: 8),
            Text(
              value != null ? value!.format(context) : '- - : - -',
              style: TextStyle(
                fontSize: 14,
                color: value != null ? _kTextPrimary : _kTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.file, required this.onTap});

  final XFile? file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_kBorderRadius),
          border: Border.all(color: _kDivider),
        ),
        child: file == null
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      color: _kTextSecondary, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Tap to add photo',
                    style: TextStyle(color: _kTextSecondary, fontSize: 14),
                  ),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(_kBorderRadius),
                child: kIsWeb
                    ? const Icon(Icons.check_circle, color: _kPurple, size: 32)
                    : Image.file(
                        io.File(file!.path),
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
              ),
      ),
    );
  }
}
