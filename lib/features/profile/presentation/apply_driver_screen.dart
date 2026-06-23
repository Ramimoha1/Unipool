import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../data/driver_verification_repository.dart';
import '../domain/driver_application.dart';

class ApplyDriverScreen extends StatefulWidget {
  const ApplyDriverScreen({super.key});

  @override
  State<ApplyDriverScreen> createState() => _ApplyDriverScreenState();
}

class _ApplyDriverScreenState extends State<ApplyDriverScreen> {
  // ─── Constants ───────────────────────────────────────────────────────────
  static const Color _teal = Color(0xFF1A9B8A);
  static const Color _bgPage = Color(0xFFF7F9FC);

  // ─── Form Key ────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  // ─── File State ──────────────────────────────────────────────────────────
  XFile? _studentCardFile;
  XFile? _driverLicenseFile;
  XFile? _vehiclePhotoFile;
  String? _studentCardName;
  String? _driverLicenseName;
  String? _vehiclePhotoName;
  bool _isSubmitting = false;

  // ─── Vehicle Details Controllers ─────────────────────────────────────────
  String _vehicleType = 'car'; // 'car' or 'motorcycle'
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();

  final _repo = DriverVerificationRepository(
    firestore: FirebaseFirestore.instance,
    storage: FirebaseStorage.instance,
  );

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _colorCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  // ─── Pick File ────────────────────────────────────────────────────────────

  Future<void> _pickFile(String docType) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked == null) return;

    setState(() {
      switch (docType) {
        case 'student_card':
          _studentCardFile = picked;
          _studentCardName = picked.name;
        case 'driver_license':
          _driverLicenseFile = picked;
          _driverLicenseName = picked.name;
        case 'vehicle_photo':
          _vehiclePhotoFile = picked;
          _vehiclePhotoName = picked.name;
      }
    });
  }

  // ─── Submit ───────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    // Validate form fields first
    if (!_formKey.currentState!.validate()) return;

    if (_studentCardFile == null || _driverLicenseFile == null || _vehiclePhotoFile == null) {
      _showSnack('Please upload all required documents and vehicle photo.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('You must be logged in to submit an application.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final studentCardUrl = await _repo.uploadDocument(
        userId: user.uid,
        file: _studentCardFile!,
        docType: 'student_card',
      );
      final driverLicenseUrl = await _repo.uploadDocument(
        userId: user.uid,
        file: _driverLicenseFile!,
        docType: 'driver_license',
      );
      final vehiclePhotoUrl = await _repo.uploadDocument(
        userId: user.uid,
        file: _vehiclePhotoFile!,
        docType: 'vehicle_photo',
      );

      final vehicleInfo = VehicleInfo(
        vehicleType: _vehicleType,
        brand: _brandCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        year: int.parse(_yearCtrl.text.trim()),
        color: _colorCtrl.text.trim(),
        plateNumber: _plateCtrl.text.trim().toUpperCase(),
        vehiclePhotoUrl: vehiclePhotoUrl,
      );

      await _repo.submitApplication(
        userId: user.uid,
        studentCardUrl: studentCardUrl,
        driverLicenseUrl: driverLicenseUrl,
        vehicleInfo: vehicleInfo,
      );

      if (!mounted) return;
      _showSnack(
        'Application submitted! We\'ll review it within 24–48 hours.',
        isError: false,
      );
      Navigator.of(context).pop(true); // pop with `true` so Profile refreshes
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : _teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      appBar: AppBar(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Apply to be a Driver',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoBanner(),
              const SizedBox(height: 24),

              // ── Section 1: Documents ─────────────────────────────────
              _SectionHeader(
                icon: Icons.description_outlined,
                title: 'Required Documents',
              ),
              const SizedBox(height: 12),
              _SectionLabel('Student Matric Card'),
              const SizedBox(height: 10),
              _UploadCard(
                label: 'Upload your matric card',
                hint: 'JPG, PNG (Max 2MB)',
                fileName: _studentCardName,
                onChoose: () => _pickFile('student_card'),
              ),
              const SizedBox(height: 20),
              _SectionLabel("Driver's License"),
              const SizedBox(height: 10),
              _UploadCard(
                label: "Upload your driver's license",
                hint: 'JPG, PNG (Max 2MB)',
                fileName: _driverLicenseName,
                onChoose: () => _pickFile('driver_license'),
              ),

              const SizedBox(height: 32),

              // ── Section 2: Vehicle Details ───────────────────────────
              _SectionHeader(
                icon: Icons.directions_car_outlined,
                title: 'Vehicle Details',
              ),
              const SizedBox(height: 16),

              // Vehicle type selector
              _SectionLabel('Vehicle Type'),
              const SizedBox(height: 8),
              _VehicleTypeSelector(
                selected: _vehicleType,
                onChanged: (v) => setState(() => _vehicleType = v),
              ),
              const SizedBox(height: 18),

              // Brand & Model row
              Row(
                children: [
                  Expanded(
                    child: _FormTextField(
                      controller: _brandCtrl,
                      label: 'Brand / Make',
                      hint: 'e.g. Toyota',
                      prefixIcon: Icons.branding_watermark_outlined,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FormTextField(
                      controller: _modelCtrl,
                      label: 'Model',
                      hint: 'e.g. Vios',
                      prefixIcon: Icons.drive_eta_outlined,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Year & Color row
              Row(
                children: [
                  Expanded(
                    child: _FormTextField(
                      controller: _yearCtrl,
                      label: 'Year',
                      hint: 'e.g. 2021',
                      prefixIcon: Icons.calendar_today_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final year = int.tryParse(v.trim());
                        if (year == null || year < 1990 || year > DateTime.now().year + 1) {
                          return 'Invalid year';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FormTextField(
                      controller: _colorCtrl,
                      label: 'Color',
                      hint: 'e.g. White',
                      prefixIcon: Icons.palette_outlined,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Plate number — full width
              _FormTextField(
                controller: _plateCtrl,
                label: 'Plate Number',
                hint: 'e.g. ABC 1234',
                prefixIcon: Icons.pin_outlined,
                textCapitalization: TextCapitalization.characters,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              // Vehicle photo
              _SectionLabel('Vehicle Photo'),
              const SizedBox(height: 4),
              const Text(
                'Take a clear photo of your vehicle showing the plate number.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280), height: 1.4),
              ),
              const SizedBox(height: 10),
              _UploadCard(
                label: 'Upload vehicle photo with plate number visible',
                hint: 'JPG, PNG (Max 2MB)',
                fileName: _vehiclePhotoName,
                onChoose: () => _pickFile('vehicle_photo'),
              ),

              const SizedBox(height: 36),

              // ── Submit Button ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _teal.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Submit Application',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF4FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFD3F5), width: 1),
      ),
      child: const Text(
        'To become a verified driver, please submit the required documents '
        'and vehicle details. Our admin team will review your application '
        'within 24–48 hours.',
        style: TextStyle(
          fontSize: 13.5,
          color: Color(0xFF3A5A99),
          height: 1.5,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF1A9B8A).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF1A9B8A)),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A2332),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF374151),
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.label,
    required this.hint,
    required this.onChoose,
    this.fileName,
  });

  final String label;
  final String hint;
  final VoidCallback onChoose;
  final String? fileName;

  static const Color _teal = Color(0xFF1A9B8A);
  static const Color _border = Color(0xFFE5EAF0);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: fileName != null ? _teal.withValues(alpha: 0.5) : _border,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            fileName != null ? Icons.check_circle_outline : Icons.upload_outlined,
            size: 32,
            color: fileName != null ? _teal : const Color(0xFF8A96A3),
          ),
          const SizedBox(height: 10),
          Text(
            fileName ?? label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: fileName != null ? _teal : const Color(0xFF4A5568),
              fontWeight:
                  fileName != null ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          if (fileName == null) ...[
            const SizedBox(height: 4),
            Text(
              hint,
              style:
                  const TextStyle(fontSize: 11.5, color: Color(0xFF8A96A3)),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: onChoose,
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                fileName != null ? 'Change File' : 'Choose File',
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Vehicle Type Selector ───────────────────────────────────────────────────

class _VehicleTypeSelector extends StatelessWidget {
  const _VehicleTypeSelector({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;


  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _TypeChip(
          icon: Icons.directions_car_outlined,
          label: 'Car',
          value: 'car',
          selected: selected,
          onTap: onChanged,
        )),
        const SizedBox(width: 12),
        Expanded(child: _TypeChip(
          icon: Icons.two_wheeler_outlined,
          label: 'Motorcycle',
          value: 'motorcycle',
          selected: selected,
          onTap: onChanged,
        )),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  static const Color _teal = Color(0xFF1A9B8A);

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? _teal.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _teal : const Color(0xFFE5EAF0),
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? _teal : const Color(0xFF8A96A3),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? _teal : const Color(0xFF4A5568),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Form Text Field ─────────────────────────────────────────────────────────

class _FormTextField extends StatelessWidget {
  const _FormTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.prefixIcon,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  static const Color _teal = Color(0xFF1A9B8A);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1A2332)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13.5),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 18, color: const Color(0xFF9CA3AF))
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5EAF0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5EAF0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _teal, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDC2626)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}