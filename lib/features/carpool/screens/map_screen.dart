import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:unipool/core/widgets/app_bottom_nav.dart';
import '../models/carpool_request_model.dart';
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
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    context.read<CarpoolProvider>().loadActiveCarpools();
    context.read<CarpoolProvider>().loadMyRequests();
    context.read<CarpoolProvider>().startOpenRequestsStream();
    _loadAllOpenRequests();
    _initializeLocation();
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

  Future<void> _initializeLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _locationEnabled = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;

      final target = LatLng(position.latitude, position.longitude);
      setState(() {
        _center = target;
        _locationEnabled = true;
      });

      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, 14),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationEnabled = false;
      });
    }
  }

  Future<void> _enableNearbyOnly() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Location permission is required to show nearby requests.';
          _showNearbyOnly = false;
          _locationEnabled = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
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
        context.read<CarpoolProvider>().loadNearbyRequests(
          position.latitude,
          position.longitude,
        );
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
    await context.read<CarpoolProvider>().loadActiveCarpools();
    if (!mounted) {
      return;
    }
    await context.read<CarpoolProvider>().loadMyRequests();
    if (!mounted) {
      return;
    }
    if (_showNearbyOnly && !context.read<CarpoolProvider>().hasActiveCarpool) {
      await context.read<CarpoolProvider>().loadNearbyRequests(
        _center.latitude,
        _center.longitude,
      );
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
    final showOnlyMyCarpool = provider.hasActiveCarpool;
    final visibleRequests = showOnlyMyCarpool
        ? provider.activeCarpools
        : (_showNearbyOnly ? provider.nearbyRequests : provider.openRequests);
    final markers = _buildMarkers(visibleRequests);

    return Scaffold(
      appBar: AppBar(title: const Text('Carpool')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _center,
                    zoom: 14,
                  ),
                  myLocationEnabled: _locationEnabled,
                  myLocationButtonEnabled: _locationEnabled,
                  markers: markers,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (_locationEnabled) {
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(_center, 14),
                      );
                    }
                  },
                ),
                DraggableScrollableSheet(
                  initialChildSize: 0.3,
                  minChildSize: 0.2,
                  maxChildSize: 0.8,
                  builder: (context, controller) {
                    return Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: ListView(
                        controller: controller,
                        padding: const EdgeInsets.all(16),
                        children: [
                          Center(
                            child: Container(
                              width: 48,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  showOnlyMyCarpool
                                      ? 'Your Carpool'
                                      : 'Open Requests',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (!showOnlyMyCarpool)
                                IconButton(
                                  onPressed: _openCreateRequest,
                                  icon: const Icon(
                                    Icons.add_circle,
                                    color: Color(0xFF0F9D8A),
                                  ),
                                ),
                            ],
                          ),
                          if (!showOnlyMyCarpool)
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _showNearbyOnly,
                              onChanged: _toggleNearbyOnly,
                              title: const Text('Nearby rides only'),
                              subtitle: const Text(
                                'Turn off to see all open requests',
                              ),
                            ),
                          const SizedBox(height: 8),
                          if (!showOnlyMyCarpool && provider.myRequests.isNotEmpty) ...[
                            Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                initiallyExpanded: false,
                                title: const Text(
                                  'My Requests',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                children: provider.myRequests.map(
                                  (request) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: RequestCard(
                                      request: request,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => RequestDetailScreen(
                                            requestId: request.id,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ).toList(),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (provider.isLoading)
                            const LinearProgressIndicator(),
                          if (provider.error != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(provider.error!),
                            ),
                          ...visibleRequests.map(
                            (request) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: RequestCard(
                                request: request,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RequestDetailScreen(
                                      requestId: request.id,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (visibleRequests.isEmpty && !provider.isLoading)
                            Padding(
                              padding: const EdgeInsets.only(top: 24),
                              child: Text(
                                showOnlyMyCarpool
                                    ? 'No active carpool yet.'
                                    : 'No open requests yet.',
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
      floatingActionButton: showOnlyMyCarpool
          ? null
          : FloatingActionButton(
               onPressed: _openCreateRequest,
               child: const Icon(Icons.add),
             ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
     );
   }

  Set<Marker> _buildMarkers(List<CarpoolRequestModel> requests) {
    final markers = <Marker>{};
    for (final request in requests) {
      final detailRoute = () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RequestDetailScreen(requestId: request.id),
        ),
      );

      markers.add(
        Marker(
          markerId: MarkerId('origin_${request.id}'),
          position: LatLng(request.originLat, request.originLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: request.originLabel, snippet: 'Origin'),
          onTap: detailRoute,
        ),
      );
      markers.add(
        Marker(
          markerId: MarkerId('destination_${request.id}'),
          position: LatLng(request.destinationLat, request.destinationLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: request.destinationLabel,
            snippet: 'Destination',
          ),
          onTap: detailRoute,
        ),
      );
    }
    return markers;
  }
}
