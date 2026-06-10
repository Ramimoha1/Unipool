import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unipool/core/widgets/app_bottom_nav.dart';
import '../providers/delivery_provider.dart';
import '../widgets/job_card.dart';
import 'post_job_screen.dart';
import 'delivery_detail_screen.dart';

class DeliveryJobsScreen extends StatefulWidget {
  const DeliveryJobsScreen({super.key});

  @override
  State<DeliveryJobsScreen> createState() => _DeliveryJobsScreenState();
}

class _DeliveryJobsScreenState extends State<DeliveryJobsScreen> {
  static const Color _purple = Color(0xFF9C27B0); // Using standard material purple as per screenshots
  String _selectedFilter = 'All Jobs';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryProvider>().startOpenJobsStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              left: 20,
              right: 20,
              bottom: 24,
            ),
            decoration: const BoxDecoration(
              color: _purple,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Delivery Jobs',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Earn while you travel',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          
          // Filters
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All Jobs',
                  isSelected: _selectedFilter == 'All Jobs',
                  onTap: () => setState(() => _selectedFilter = 'All Jobs'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Verified Only',
                  isSelected: _selectedFilter == 'Verified Only',
                  onTap: () => setState(() => _selectedFilter = 'Verified Only'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'High Pay',
                  isSelected: _selectedFilter == 'High Pay',
                  onTap: () => setState(() => _selectedFilter = 'High Pay'),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: Consumer<DeliveryProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.openJobs.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.error != null && provider.openJobs.isEmpty) {
                  return Center(child: Text(provider.error!));
                }
                if (provider.openJobs.isEmpty) {
                  return const Center(child: Text('No delivery jobs available.'));
                }

                // TODO: Apply actual filter logic here if needed
                final jobs = provider.openJobs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: jobs.length,
                  itemBuilder: (context, index) {
                    final job = jobs[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: JobCard(
                        job: job,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DeliveryDetailScreen(job: job),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PostJobScreen()),
          );
        },
        backgroundColor: _purple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  static const Color _purple = Color(0xFF9C27B0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _purple : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _purple : const Color(0xFFD9E2EC),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF486581),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
