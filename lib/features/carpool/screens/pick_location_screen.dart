import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

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
  static const LatLng _utmMalaysia = LatLng(1.5594, 103.6386);

  final _searchController = TextEditingController();
  GoogleMapController? _mapController;
  Timer? _debounce;

  final _uuid = const Uuid();
  String _sessionToken = '';
  String _placesApiKey = '';
  List<_PlaceSuggestion> _suggestions = [];
  bool _loadingSuggestions = false;
  bool _suppressAutocomplete = false;

  late LatLng _currentTarget;
  String _currentLabel = '';
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _sessionToken = _uuid.v4();
    _placesApiKey = _resolvePlacesKey();
    _searchController.addListener(
      () => _onQueryChanged(_searchController.text),
    );
    _currentTarget = (widget.initialLat != null && widget.initialLng != null)
        ? LatLng(widget.initialLat!, widget.initialLng!)
        : _utmMalaysia;
    _currentLabel = widget.initialLabel;

    if (widget.initialLat == null && widget.initialLng == null) {
      _moveToCurrentLocation(silent: true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  String _resolvePlacesKey() {
    if (!dotenv.isInitialized) {
      return '';
    }
    return dotenv.env['MAPS_API_KEY']?.trim() ??
        dotenv.env['MAPS_API_KEY_ANDROID']?.trim() ??
        dotenv.env['MAPS_API_KEY_IOS']?.trim() ??
        dotenv.env['MAPS_API_KEY_WEB']?.trim() ??
        '';
  }

  void _onQueryChanged(String query) {
    if (_suppressAutocomplete) {
      _suppressAutocomplete = false;
      return;
    }
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      if (_suggestions.isNotEmpty) {
        setState(() => _suggestions = []);
      }
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchAutocomplete(trimmed);
    });
  }

  Future<void> _fetchAutocomplete(String query) async {
    if (_placesApiKey.isEmpty && !kIsWeb) return;

    setState(() => _loadingSuggestions = true);
    try {
      final predictions = kIsWeb
          ? await _fetchWebAutocomplete(query)
          : await _fetchGoogleAutocomplete(query);

      if (mounted) {
        setState(() => _suggestions = predictions);
      }
    } catch (_) {
      // Ignore network failures and keep the existing UI.
    } finally {
      if (mounted) {
        setState(() => _loadingSuggestions = false);
      }
    }
  }

  Future<List<_PlaceSuggestion>> _fetchGoogleAutocomplete(String query) async {
    final params = <String, String>{
      'input': query,
      'key': _placesApiKey,
      'sessiontoken': _sessionToken,
      'location': '${_currentTarget.latitude},${_currentTarget.longitude}',
      'radius': '50000',
    };

    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      params,
    );
    final response = await http.get(url);
    if (response.statusCode != 200) {
      return const [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final status = data['status'] as String? ?? '';
    if (status != 'OK' && status != 'ZERO_RESULTS') {
      return const [];
    }

    return (data['predictions'] as List<dynamic>? ?? [])
        .map((item) => _PlaceSuggestion.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<_PlaceSuggestion>> _fetchWebAutocomplete(String query) async {
    final url = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '5',
    });
    final response = await http.get(
      url,
      headers: const {'Accept': 'application/json'},
    );
    if (response.statusCode != 200) {
      return const [];
    }

    final results = jsonDecode(response.body) as List<dynamic>;
    return results
        .map(
          (item) => _PlaceSuggestion.fromWebMap(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> _selectSuggestion(_PlaceSuggestion suggestion) async {
    if (_placesApiKey.isEmpty && !kIsWeb) {
      return;
    }
    try {
      if (kIsWeb &&
          suggestion.latitude != null &&
          suggestion.longitude != null) {
        final target = LatLng(suggestion.latitude!, suggestion.longitude!);
        if (!mounted) return;

        setState(() {
          _currentTarget = target;
          _currentLabel = suggestion.mainText;
          _suggestions = [];
          _suppressAutocomplete = true;
          _searchController.text = suggestion.mainText;
        });

        await _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(target, 16),
        );
        return;
      }

      final url =
          Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
            'place_id': suggestion.placeId,
            'fields': 'geometry,name,formatted_address',
            'key': _placesApiKey,
            'sessiontoken': _sessionToken,
          });

      final response = await http.get(url);
      if (response.statusCode != 200) {
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String? ?? '';
      if (status != 'OK') {
        return;
      }

      final result = data['result'] as Map<String, dynamic>?;
      final geometry = result?['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;
      if (location == null) {
        return;
      }

      final lat = (location['lat'] as num?)?.toDouble();
      final lng = (location['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) {
        return;
      }

        final label =
          (result?['name'] as String?)?.trim().isNotEmpty == true
          ? (result?['name'] as String).trim()
          : suggestion.mainText;

      final target = LatLng(lat, lng);
      if (!mounted) return;

      setState(() {
        _currentTarget = target;
        _currentLabel = label;
        _suggestions = [];
        _suppressAutocomplete = true;
        _searchController.text = label;
      });

      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, 16),
      );
    } catch (_) {
      _showMessage('Failed to load place details.');
    }
  }

  Future<void> _moveToCurrentLocation({bool silent = false}) async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!silent) _showMessage('Location permission denied.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final target = LatLng(position.latitude, position.longitude);
      if (!mounted) {
        return;
      }

      setState(() {
        _currentTarget = target;
      });

      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, 16),
      );
      await _updateLabelFromCoordinates(target, fallback: 'Current location');
    } catch (_) {
      if (!silent) _showMessage('Failed to get current location.');
    }
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      return;
    }

    setState(() => _searching = true);
    try {
      if (kIsWeb) {
        final webResults = await _fetchWebAutocomplete(query);
        if (webResults.isNotEmpty) {
          await _selectSuggestion(webResults.first);
          return;
        }
      }

      if (_placesApiKey.isNotEmpty) {
        final url = Uri.https(
          'maps.googleapis.com',
          '/maps/api/place/findplacefromtext/json',
          {
            'input': query,
            'inputtype': 'textquery',
            'fields': 'geometry,formatted_address,name',
            'key': _placesApiKey,
            'sessiontoken': _sessionToken,
          },
        );
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = data['candidates'] as List<dynamic>? ?? [];
          if (candidates.isNotEmpty) {
            final first = candidates.first as Map<String, dynamic>;
            final geometry = first['geometry'] as Map<String, dynamic>?;
            final location = geometry?['location'] as Map<String, dynamic>?;
            final lat = (location?['lat'] as num?)?.toDouble();
            final lng = (location?['lng'] as num?)?.toDouble();
            if (lat != null && lng != null) {
                final label =
                  (first['name'] as String?)?.trim().isNotEmpty == true
                  ? (first['name'] as String).trim()
                  : query;
              final target = LatLng(lat, lng);
              setState(() {
                _currentTarget = target;
                _currentLabel = label;
                _suggestions = [];
                _suppressAutocomplete = true;
                _searchController.text = label;
              });
              await _mapController?.animateCamera(
                CameraUpdate.newLatLngZoom(target, 16),
              );
              return;
            }
          }
        }
      }

      final locations = await locationFromAddress(query);
      if (locations.isEmpty) {
        _showMessage('No location found for your search.');
        return;
      }

      final first = locations.first;
      final target = LatLng(first.latitude, first.longitude);

      setState(() {
        _currentTarget = target;
        _suggestions = [];
      });

      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, 16),
      );
      await _updateLabelFromCoordinates(target, fallback: query);
    } catch (_) {
      _showMessage('Address search failed. Try another search text.');
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _updateLabelFromCoordinates(
    LatLng point, {
    String fallback = '',
  }) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
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
      _suggestions = [];
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final marker = Marker(
      markerId: const MarkerId('selected_location'),
      position: _currentTarget,
      infoWindow: InfoWindow(
        title: _currentLabel.isEmpty ? 'Selected location' : _currentLabel,
      ),
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
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Search'),
                ),
              ],
            ),
          ),
          if (_loadingSuggestions)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    return ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(suggestion.mainText),
                      subtitle: suggestion.secondaryText.isEmpty
                          ? null
                          : Text(suggestion.secondaryText),
                      onTap: () => _selectSuggestion(suggestion),
                    );
                  },
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _currentLabel.isEmpty
                        ? 'Tap map to pin a location'
                        : _currentLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => _moveToCurrentLocation(silent: false),
                  icon: const Icon(Icons.my_location),
                  tooltip: 'Use current location',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentTarget,
                zoom: 14,
              ),
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

class _PlaceSuggestion {
  const _PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
    this.latitude,
    this.longitude,
  });

  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
  final double? latitude;
  final double? longitude;

  factory _PlaceSuggestion.fromMap(Map<String, dynamic> map) {
    final structured =
        map['structured_formatting'] as Map<String, dynamic>? ?? const {};
    return _PlaceSuggestion(
      placeId: map['place_id'] as String? ?? '',
      description: map['description'] as String? ?? '',
      mainText:
          structured['main_text'] as String? ??
          (map['description'] as String? ?? ''),
      secondaryText: structured['secondary_text'] as String? ?? '',
    );
  }

  factory _PlaceSuggestion.fromWebMap(Map<String, dynamic> map) {
    return _PlaceSuggestion(
      placeId: map['place_id'] as String? ?? '',
      description: map['display_name'] as String? ?? '',
      mainText:
          map['name'] as String? ?? (map['display_name'] as String? ?? ''),
      secondaryText: (map['display_name'] as String?)?.contains(',') == true
          ? (map['display_name'] as String)
                .split(',')
                .skip(1)
                .take(2)
                .join(', ')
          : '',
      latitude: double.tryParse(map['lat']?.toString() ?? ''),
      longitude: double.tryParse(map['lon']?.toString() ?? ''),
    );
  }
}
