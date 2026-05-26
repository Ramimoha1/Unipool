import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/carpool_provider.dart';
import '../widgets/request_card.dart';
import 'create_request_screen.dart';
import 'request_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng _center = const LatLng(1.2966, 103.7764);
  bool _loading = true;
  String? _error;
  bool _showNearbyOnly = false;
  bool _locationEnabled = false;

  @override
  void initState() {
    super.initState();
    context.read<CarpoolProvider>().loadMyRequests();
    context.read<CarpoolProvider>().startOpenRequestsStream();
    _loadAllOpenRequests();
  }

  Future<void> _loadAllOpenRequests() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _error = null;
    });
  }

  Future<void> _enableNearbyOnly() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Location permission is required to show nearby requests.';
          _showNearbyOnly = false;
          _locationEnabled = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _center = LatLng(position.latitude, position.longitude);
        _showNearbyOnly = true;
        _locationEnabled = true;
        _error = null;
      });

      if (mounted) {
        context.read<CarpoolProvider>().loadNearbyRequests(position.latitude, position.longitude);
      }
    } catch (exception) {
      setState(() {
        _error = 'Failed to get location: $exception';
        _showNearbyOnly = false;
        _locationEnabled = false;
      });
    }
  }

  Future<void> _refreshRequests() async {
    if (!mounted) {
      return;
    }
    await context.read<CarpoolProvider>().loadMyRequests();
    if (!mounted) {
      return;
    }
    if (_showNearbyOnly) {
      await context.read<CarpoolProvider>().loadNearbyRequests(_center.latitude, _center.longitude);
    }
  }

  Future<void> _toggleNearbyOnly(bool value) async {
    setState(() {
      _showNearbyOnly = value;
      _error = null;
    });

    if (value) {
      await _enableNearbyOnly();
    } else {
      await _loadAllOpenRequests();
    }
  }

  Future<void> _openCreateRequest() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateRequestScreen()),
    );
    if (created == true) {
      await _refreshRequests();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CarpoolProvider>();
    final visibleRequests = _showNearbyOnly ? provider.nearbyRequests : provider.openRequests;
    final markers = visibleRequests.map((request) {
      return Marker(
        markerId: MarkerId(request.id),
        position: LatLng(request.originLat, request.originLng),
        infoWindow: InfoWindow(title: request.originLabel, snippet: request.destinationLabel),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RequestDetailScreen(requestId: request.id)),
        ),
      );
    }).toSet();

    return Scaffold(
      appBar: AppBar(title: const Text('Carpool')), 
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(target: _center, zoom: 14),
                      myLocationEnabled: _locationEnabled,
                      myLocationButtonEnabled: _locationEnabled,
                      markers: markers,
                    ),
                    DraggableScrollableSheet(
                      initialChildSize: 0.3,
                      minChildSize: 0.2,
                      maxChildSize: 0.8,
                      builder: (context, controller) {
                        return Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          child: ListView(
                            controller: controller,
                            padding: const EdgeInsets.all(16),
                            children: [
                              Center(child: Container(width: 48, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(999)))),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Expanded(child: Text('Open Requests', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                                  IconButton(
                                    onPressed: _openCreateRequest,
                                    icon: const Icon(Icons.add_circle, color: Color(0xFF0F9D8A)),
                                  ),
                                ],
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _showNearbyOnly,
                                onChanged: _toggleNearbyOnly,
                                title: const Text('Nearby rides only'),
                                subtitle: const Text('Turn off to see all open requests'),
                              ),
                              const SizedBox(height: 8),
                              if (provider.myRequests.isNotEmpty) ...[
                                const Text('My Requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 8),
                                ...provider.myRequests.map((request) => Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: RequestCard(
                                        request: request,
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => RequestDetailScreen(requestId: request.id)),
                                        ),
                                      ),
                                    )),
                                const SizedBox(height: 8),
                              ],
                              if (provider.isLoading) const LinearProgressIndicator(),
                              if (provider.error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(provider.error!)),
                              ...visibleRequests.map((request) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: RequestCard(
                                      request: request,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => RequestDetailScreen(requestId: request.id)),
                                      ),
                                    ),
                                  )),
                              if (visibleRequests.isEmpty && !provider.isLoading)
                                const Padding(
                                  padding: EdgeInsets.only(top: 24),
                                  child: Text('No open requests yet.'),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateRequest,
        child: const Icon(Icons.add),
      ),
    );
  }
}