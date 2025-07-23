import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationPickerScreen extends StatefulWidget {
  final LatLng initialLatLng;
  const LocationPickerScreen({super.key, required this.initialLatLng});

  @override
  _LocationPickerScreenState createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng? _selectedLatLng;
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
  final _tileProvider = FMTCTileProvider(
    stores: const {'mapStore': BrowseStoreStrategy.readUpdateCreate},
  );
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchLocation() async {
    final searchText = _searchController.text.trim();
    if (searchText.isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$searchText&format=json&limit=5',
        ),
        headers: {'User-Agent': 'GeofenceLoggingApp/1.0'},
      );
      final results = json.decode(response.body);
      if (results.isNotEmpty && context.mounted) {
        showModalBottomSheet(
          context: context,
          builder: (context) => ListView(
            children: results.map<Widget>((result) => ListTile(
              title: Text(result['display_name'] ?? 'Unknown'),
              onTap: () {
                final lat = double.parse(result['lat']);
                final lon = double.parse(result['lon']);
                final latLng = LatLng(lat, lon);
                setState(() => _selectedLatLng = latLng);
                _mapController.move(latLng, 15);
                Navigator.pop(context);
              },
            )).toList(),
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingen resultater fundet')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fejl ved søgning: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    if (currentZoom < 19) {
      _mapController.move(_mapController.camera.center, currentZoom + 1);
    }
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    if (currentZoom > 10) {
      _mapController.move(_mapController.camera.center, currentZoom - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vælg sted')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Stack(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Søg efter sted',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _searchLocation(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _searchLocation,
                    ),
                  ],
                ),
                if (_isSearching)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: widget.initialLatLng,
                    initialZoom: 15,
                    minZoom: 10,
                    maxZoom: 19,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _selectedLatLng = point;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.hojmoseit.sps_helper',
                      tileProvider: _tileProvider,
                    ),
                    if (_selectedLatLng != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLatLng!,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Positioned(
                  right: 16,
                  bottom: 80,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        heroTag: 'zoomIn',
                        mini: true,
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        onPressed: _zoomIn,
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: 'zoomOut',
                        mini: true,
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        onPressed: _zoomOut,
                        child: const Icon(Icons.remove),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: _selectedLatLng != null
                  ? () => Navigator.pop(context, _selectedLatLng)
                  : null,
              child: const Text('Er det her?'),
            ),
          ),
        ],
      ),
    );
  }
}
