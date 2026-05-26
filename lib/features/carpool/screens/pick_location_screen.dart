import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PickLocationScreen extends StatefulWidget {
  const PickLocationScreen({
    super.key,
    required this.title,
    required this.initialLabel,
    required this.initialLat,
    required this.initialLng,
  });

  final String title;
  final String initialLabel;
  final double? initialLat;
  final double? initialLng;

  @override
  State<PickLocationScreen> createState() => _PickLocationScreenState();
}

class _PickLocationScreenState extends State<PickLocationScreen> {
  static const LatLng _defaultCenter = LatLng(1.2966, 103.7764);

  final _searchController = TextEditingController();
  GoogleMapController? _mapController;

  late LatLng _currentTarget;
  String _currentLabel = '';
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _currentTarget = (widget.initialLat != null && widget.initialLng != null)
        ? LatLng(widget.initialLat!, widget.initialLng!)
        : _defaultCenter;
    _currentLabel = widget.initialLabel;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _moveToCurrentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _showMessage('Location permission denied.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final target = LatLng(position.latitude, position.longitude);
      if (!mounted) {
        return;
      }

      setState(() {
        _currentTarget = target;
      });

      await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
      await _updateLabelFromCoordinates(target, fallback: 'Current location');
    } catch (_) {
      _showMessage('Failed to get current location.');
    }
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      return;
    }

    setState(() => _searching = true);
    try {
      final locations = await locationFromAddress(query);
      if (locations.isEmpty) {
        _showMessage('No location found for your search.');
        return;
      }

      final first = locations.first;
      final target = LatLng(first.latitude, first.longitude);

      setState(() {
        _currentTarget = target;
      });

      await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
      await _updateLabelFromCoordinates(target, fallback: query);
    } catch (_) {
      _showMessage('Address search failed. Try another search text.');
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _updateLabelFromCoordinates(LatLng point, {String fallback = ''}) async {
    try {
      final placemarks = await placemarkFromCoordinates(point.latitude, point.longitude);
      if (!mounted) {
        return;
      }

      final first = placemarks.isNotEmpty ? placemarks.first : null;
      final parts = <String>[
        if ((first?.name ?? '').trim().isNotEmpty) first!.name!.trim(),
        if ((first?.street ?? '').trim().isNotEmpty) first!.street!.trim(),
        if ((first?.locality ?? '').trim().isNotEmpty) first!.locality!.trim(),
      ];
      final resolved = parts.join(', ');

      setState(() {
        _currentLabel = resolved.isNotEmpty ? resolved : fallback;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentLabel = fallback;
      });
    }
  }

  void _onMapTapped(LatLng point) {
    setState(() {
      _currentTarget = point;
    });
    _updateLabelFromCoordinates(point, fallback: 'Pinned location');
  }

  void _confirmSelection() {
    final label = _currentLabel.trim().isEmpty
        ? '${_currentTarget.latitude.toStringAsFixed(5)}, ${_currentTarget.longitude.toStringAsFixed(5)}'
        : _currentLabel.trim();

    Navigator.pop(context, {
      'label': label,
      'lat': _currentTarget.latitude,
      'lng': _currentTarget.longitude,
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final marker = Marker(
      markerId: const MarkerId('selected_location'),
      position: _currentTarget,
      infoWindow: InfoWindow(title: _currentLabel.isEmpty ? 'Selected location' : _currentLabel),
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchAddress(),
                    decoration: const InputDecoration(
                      hintText: 'Search place or address',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _searching ? null : _searchAddress,
                  child: _searching
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Search'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _currentLabel.isEmpty ? 'Tap map to pin a location' : _currentLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: _moveToCurrentLocation,
                  icon: const Icon(Icons.my_location),
                  tooltip: 'Use current location',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _currentTarget, zoom: 14),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              markers: {marker},
              onMapCreated: (controller) => _mapController = controller,
              onTap: _onMapTapped,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _confirmSelection,
                icon: const Icon(Icons.check),
                label: const Text('Use this location'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
