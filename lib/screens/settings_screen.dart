import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/geofence_service.dart';
import '../services/notification_service.dart';
import '../models/school_schedule.dart';
import '../models/geofence_location.dart';
import '../widgets/schedule_picker_dialog.dart';
import '../widgets/location_details_dialog.dart';
import 'location_picker_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GeofenceService _geofenceService = GeofenceService();
  final NotificationService _notificationService = NotificationService();
  List<GeofenceLocation> _locations = [];
  SchoolSchedule? _schedule;
  bool _isLoading = true;
  String? _selectedProvider;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _geofenceService.initialize();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _locations = _geofenceService.locations;
      _schedule = _geofenceService.schedule;
      _selectedProvider = prefs.getString('sps_provider');
      _isLoading = false;
    });
  }

  Future<void> _onProviderChanged(String? newValue) async {
    if (newValue == null) return;
    setState(() {
      _selectedProvider = newValue;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sps_provider', newValue);
    await _notificationService.scheduleMonthlyReminder(newValue);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reminder set for $_selectedProvider')),
    );
  }

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
            title: const Text('SPS-leverandør'),
            trailing: DropdownButton<String>(
              value: _selectedProvider,
              hint: const Text('Vælg leverandør'),
              items: ['DUOS', 'Handicapformidlingen']
                  .map((provider) => DropdownMenuItem(
                        value: provider,
                        child: Text(provider),
                      ))
                  .toList(),
              onChanged: _onProviderChanged,
            ),
          ),
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
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _notificationService.sendTestNotification(),
            child: const Text('Test Notification'),
          ),
        ],
      ),
    );
  }
}