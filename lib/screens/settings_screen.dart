import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/geofence_service.dart';
import '../models/school_schedule.dart';
import '../models/geofence_location.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GeofenceService _geofenceService = GeofenceService();
  List<GeofenceLocation> _locations = [];
  SchoolSchedule? _schedule;
  bool _isLoading = true;

  String getDayName(int dayOfWeek) {
    switch (dayOfWeek) {
      case 1:
        return 'Mandag';
      case 2:
        return 'Tirsdag';
      case 3:
        return 'Onsdag';
      case 4:
        return 'Torsdag';
      case 5:
        return 'Fredag';
      default:
        return 'Ukendt';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _geofenceService.initialize();
    setState(() {
      _locations = _geofenceService.locations;
      _schedule = _geofenceService.schedule;
      _isLoading = false;
    });
  }

  Future<void> _pickSchedule() async {
    final newSchedule = await showDialog<SchoolSchedule>(
      context: context,
      builder: (context) => SchedulePickerDialog(schedule: _schedule),
    );
    if (newSchedule != null) {
      await _geofenceService.updateSchedule(newSchedule);
      setState(() {
        _schedule = newSchedule;
      });
    }
  }

  Future<void> _pickLocation() async {
    final position = await _geofenceService.getCurrentPosition();
    final initialLatLng = position != null
        ? LatLng(position.latitude, position.longitude)
        : const LatLng(59.9399, 10.7215); // Fallback

    final latLng = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initialLatLng: initialLatLng),
      ),
    );

    if (latLng is LatLng && context.mounted) {
      final result = await showDialog<GeofenceLocation>(
        context: context,
        builder: (context) => LocationDetailsDialog(latLng: latLng),
      );
      if (result != null) {
        setState(() {
          _locations.add(result);
        });
        await _geofenceService.updateLocations(_locations);
      }
    } else if (context.mounted && position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kan ikke finde din position, vælger standarden')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Indstillinger')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Skema'),
            subtitle: Text(_schedule?.weeklySchedule.isEmpty ?? true
                ? 'Ikke sat'
                : 'Sat til ${_schedule!.weeklySchedule.length} dage'),
            trailing: const Icon(Icons.edit),
            onTap: _pickSchedule,
          ),
          ListTile(
            title: const Text('Skolens bygninger'),
            subtitle: Text('${_locations.length} lokationer'),
            trailing: const Icon(Icons.add_location),
            onTap: _pickLocation,
          ),
          const SizedBox(height: 16),
          const Text('Lokationer', style: TextStyle(fontWeight: FontWeight.bold)),
          ..._locations.asMap().entries.map((entry) {
            final index = entry.key;
            final loc = entry.value;
            return ListTile(
                title: Text('${loc.name} (${getDayName(loc.dayOfWeek)})'),
              subtitle: Text('Latitude: ${loc.latitude}, Longitude: ${loc.longitude}, Radius: ${loc.radius}m'),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  setState(() {
                    _locations.removeAt(index);
                  });
                  await _geofenceService.updateLocations(_locations);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class SchedulePickerDialog extends StatefulWidget {
  final SchoolSchedule? schedule;
  const SchedulePickerDialog({super.key, this.schedule});

  @override
  _SchedulePickerDialogState createState() => _SchedulePickerDialogState();
}

class _SchedulePickerDialogState extends State<SchedulePickerDialog> {
  late Map<int, List<TimeRange>> _weeklySchedule;

  @override
  void initState() {
    super.initState();
    _weeklySchedule = widget.schedule?.weeklySchedule ?? {};
  }

  Future<void> _addTimeRange(int day) async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (start == null) return;
    final end = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 16, minute: 0),
    );
    if (end == null) return;
    setState(() {
      _weeklySchedule[day] = _weeklySchedule[day] ?? [];
      _weeklySchedule[day]!.add(TimeRange(start: start, end: end));
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Vælg skema'),
      content: SingleChildScrollView(
        child: Column(
          children: List.generate(5, (index) {
            final day = index + 1;
            final dayName = ['Mandag', 'Tirsdag', 'Onsdag', 'Torsdag', 'Fredag'][index];
            return ExpansionTile(
              title: Text(dayName),
              children: [
                ...( _weeklySchedule[day] ?? []).asMap().entries.map((entry) {
                  final range = entry.value;
                  return ListTile(
                    title: Text('${range.start.format(context)} - ${range.end.format(context)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          _weeklySchedule[day]!.removeAt(entry.key);
                          if (_weeklySchedule[day]!.isEmpty) _weeklySchedule.remove(day);
                        });
                      },
                    ),
                  );
                }),
                TextButton(
                  onPressed: () => _addTimeRange(day),
                  child: const Text('Tilføj tidsrum'),
                ),
              ],
            );
          }),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            SchoolSchedule(weeklySchedule: _weeklySchedule, isActive: true),
          ),
          child: const Text('Gem'),
        ),
      ],
    );
  }
}

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

class LocationDetailsDialog extends StatefulWidget {
  final LatLng latLng;
  const LocationDetailsDialog({super.key, required this.latLng});

  @override
  _LocationDetailsDialogState createState() => _LocationDetailsDialogState();
}

class _LocationDetailsDialogState extends State<LocationDetailsDialog> {
  String _name = '';
  double _radius = 100;
  int _dayOfWeek = 1;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    http.get(
      Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${widget.latLng.latitude}&lon=${widget.latLng.longitude}&format=json',
      ),
      headers: {'User-Agent': 'GeofenceLoggingApp/1.0'},
    ).then((response) {
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final address = data['display_name'] ?? '';
        setState(() {
          //_name = address;
          //_nameController.text = address;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Detaljer for lokation'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Navn'),
              onChanged: (value) => _name = value,
            ),
            DropdownButton<int>(
              value: _dayOfWeek,
              items: List.generate(5, (i) => i + 1).map((day) {
                return DropdownMenuItem(
                  value: day,
                  child: Text(['Man', 'Tir', 'Ons', 'Tor', 'Fre'][day - 1]),
                );
              }).toList(),
              onChanged: (value) => setState(() => _dayOfWeek = value!),
            ),
            Slider(
              value: _radius,
              min: 50,
              max: 500,
              divisions: 9,
              label: '${_radius.round()}m',
              onChanged: (value) => setState(() => _radius = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: _name.isNotEmpty
              ? () => Navigator.pop(
                    context,
                    GeofenceLocation(
                      dayOfWeek: _dayOfWeek,
                      latitude: widget.latLng.latitude,
                      longitude: widget.latLng.longitude,
                      radius: _radius,
                      name: _name,
                    ),
                  )
              : null,
          child: const Text('Gem'),
        ),
      ],
    );
  }
}