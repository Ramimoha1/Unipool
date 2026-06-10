import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:unipool/core/widgets/app_bottom_nav.dart';
import '../models/delivery_job_model.dart';
import '../providers/delivery_provider.dart';

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  static const Color _purple = Color(0xFF9C27B0);
  
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _itemNameController = TextEditingController();
  final _payController = TextEditingController();
  
  List<TextEditingController> _stopControllers = [TextEditingController()];
  int _quantity = 1;
  
  DateTime _startTime = DateTime.now().add(const Duration(hours: 1));
  DateTime _endTime = DateTime.now().add(const Duration(hours: 3));

  @override
  void dispose() {
    _pickupController.dispose();
    _itemNameController.dispose();
    _payController.dispose();
    for (var c in _stopControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _selectTime(bool isStart) async {
    final initial = isStart ? _startTime : _endTime;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time != null) {
      final now = DateTime.now();
      setState(() {
        if (isStart) {
          _startTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
        } else {
          _endTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
        }
      });
    }
  }

  void _postJob() async {
    if (!_formKey.currentState!.validate()) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first.')),
      );
      return;
    }

    final stops = _stopControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .map((label) => {'label': label, 'lat': 0.0, 'lng': 0.0}) // Placeholders for lat/lng
        .toList();

    if (stops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one delivery stop.')),
      );
      return;
    }

    final job = DeliveryJobModel(
      id: '',
      createdBy: user.uid,
      sellerId: user.uid,
      title: _itemNameController.text.trim(),
      pickupLabel: _pickupController.text.trim(),
      pickupLat: 0.0,
      pickupLng: 0.0,
      deliveryStops: stops,
      deliveryTime: DateTime.now(), // Legacy field
      timeWindowStart: _startTime,
      timeWindowEnd: _endTime,
      items: [
        {'name': _itemNameController.text.trim(), 'description': ''}
      ],
      quantity: _quantity,
      price: double.parse(_payController.text.trim()),
      allowedDrivers: 'all',
      jobStatus: 'open',
      assignedDriverId: '',
      sellerApprovedDriverId: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await context.read<DeliveryProvider>().createJob(job);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create job: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF1A2332)),
        title: const Text(
          'Post Delivery Job',
          style: TextStyle(
            color: Color(0xFF1A2332),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Consumer<DeliveryProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Pickup Location'),
                  _buildTextField(
                    controller: _pickupController,
                    hintText: 'e.g., NUS Utown',
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle('Delivery Stops'),
                  ...List.generate(_stopControllers.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildTextField(
                        controller: _stopControllers[index],
                        hintText: 'Stop ${index + 1}',
                        icon: Icons.flag_outlined,
                        suffixIcon: index > 0
                            ? IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _stopControllers[index].dispose();
                                    _stopControllers.removeAt(index);
                                  });
                                },
                              )
                            : null,
                      ),
                    );
                  }),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _stopControllers.add(TextEditingController());
                      });
                    },
                    child: const Text(
                      '+ Add another stop',
                      style: TextStyle(
                        color: _purple,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Item Name'),
                  _buildTextField(
                    controller: _itemNameController,
                    hintText: 'e.g., Textbooks',
                    icon: Icons.inventory_2_outlined,
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('Quantity'),
                            Container(
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFD9E2EC)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, color: _purple),
                                    onPressed: () {
                                      if (_quantity > 1) setState(() => _quantity--);
                                    },
                                  ),
                                  Text(
                                    '$_quantity',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A2332),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add, color: _purple),
                                    onPressed: () {
                                      setState(() => _quantity++);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('Pay Offered'),
                            _buildTextField(
                              controller: _payController,
                              hintText: '\$',
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Time Window'),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _selectTime(true),
                          child: Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFD9E2EC)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, color: Color(0xFF8A96A3), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('h:mm a').format(_startTime),
                                  style: const TextStyle(fontSize: 15, color: Color(0xFF1A2332)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('to', style: TextStyle(color: Color(0xFF8A96A3))),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _selectTime(false),
                          child: Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFD9E2EC)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, color: Color(0xFF8A96A3), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('h:mm a').format(_endTime),
                                  style: const TextStyle(fontSize: 15, color: Color(0xFF1A2332)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _postJob,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Post Job',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A2332),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    IconData? icon,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Required field';
        }
        return null;
      },
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFFB0BAC8)),
        prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF8A96A3), size: 22) : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD9E2EC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD9E2EC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _purple),
        ),
      ),
    );
  }
}
