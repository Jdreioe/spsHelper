import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/geofence_location.dart';
import '../models/school_schedule.dart';
import '../models/log_entry.dart';
import 'database_service.dart';

class GeofenceService {
  static final GeofenceService _instance = GeofenceService._internal();
  factory GeofenceService() => _instance;
  GeofenceService._internal();

  final DatabaseService _dbService = DatabaseService();
  List<GeofenceLocation> _locations = [];
  SchoolSchedule? _schedule;
  Timer? _timer;

  // Public getters
  SchoolSchedule? get schedule => _schedule;
  List<GeofenceLocation> get locations => _locations;

  Future<void> initialize() async {
    await _dbService.initialize();
    await _requestPermissions();
    await _loadLocations();
    await _loadSchedule();
    _startPeriodicCheck();
  }

  void dispose() {
    _timer?.cancel();
  }


  Future<void> _requestPermissions() async {
    await Permission.locationWhenInUse.request();
    await Permission.locationAlways.request();
    if (Platform.isAndroid) {
      await Permission.storage.request();
    }
  }

  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return null;
    }
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _loadLocations() async {
    _locations = await _dbService.getLocations();
  }

  Future<void> _loadSchedule() async {
    _schedule = await _dbService.getSchedule();
    if (_schedule == null) {
      _schedule = SchoolSchedule(weeklySchedule: {}, isActive: true);
    }
  }

  

  void _startPeriodicCheck() {
    _timer?.cancel(); // Cancel any existing timer
    _timer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _checkGeofenceStatus();
    });
  }

  Future<void> _checkGeofenceStatus() async {
    if (!_isWithinSchedule()) {
      print('Outside of schedule, skipping geofence check.');
      return;
    }

    print('--- Starting Geofence Check ---');
    final position = await getCurrentPosition();
    if (position == null) {
      print('Could not get current position.');
      logEvent('Error', 'Could not get location');
      return;
    }
    print('Current Position: ${position.latitude}, ${position.longitude}');

    final today = DateTime.now().weekday;
    final todayLocations = _locations.where((loc) => loc.dayOfWeek == today).toList();

    if (todayLocations.isEmpty) {
      print('No locations scheduled for today.');
    }

    for (var loc in todayLocations) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        loc.latitude,
        loc.longitude,
      );
      print('Distance to ${loc.name}: ${distance.toStringAsFixed(2)} meters');

      if (distance <= loc.radius) {
        print('*** ENTERED GEOFENCE: ${loc.name} ***');
        logEvent('Enter', loc.name);
      } else {
        print('Outside of geofence for ${loc.name}');
        logEvent('Exit', loc.name);
      }
    }
    print('--- Finished Geofence Check ---');
  }

  bool _isWithinSchedule() {
    print('--- Checking Schedule ---');
    if (_schedule == null) {
      print('Schedule is null.');
      return true;
    }
    if (!_schedule!.isActive) {
      print('Schedule is not active.');
      return true;
    }

    final now = DateTime.now();
    final today = now.weekday;
    final currentTime = TimeOfDay.fromDateTime(now);
    print('Current Time: ${currentTime.hour}:${currentTime.minute}');
    print('Today\'s Day: $today');

    final todaySchedule = _schedule!.weeklySchedule[today] ?? [];
    print('Today\'s Schedule:');
    if (todaySchedule.isEmpty) {
      print('  - No schedule for today.');
    }
    for (var range in todaySchedule) {
      print('  - ${range.start.hour}:${range.start.minute} to ${range.end.hour}:${range.end.minute}');
    }

    final result = todaySchedule.any((range) =>
        _compareTimeOfDay(currentTime, range.start) >= 0 &&
        _compareTimeOfDay(currentTime, range.end) <= 0);
    print('--- Finished Schedule Check (Result: $result) ---');
    return result;
  }

  int _compareTimeOfDay(TimeOfDay t1, TimeOfDay t2) {
    final t1Minutes = t1.hour * 60 + t1.minute;
    final t2Minutes = t2.hour * 60 + t2.minute;
    return t1Minutes.compareTo(t2Minutes);
  }

  Future<void> logEvent(String event, String location) async {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      event: event,
      location: location,
    );
    await _dbService.insertLog(entry);
  }

  Future<List<LogEntry>> getLogs() async {
    return await _dbService.getLogs();
  }

  Future<void> deleteLog(int id) async {
    await _dbService.deleteLog(id);
  }

  Future<void> exportLogs(BuildContext context) async {
    try {
      final logs = await _dbService.getLogs();
      final csv = 'Timestamp,Event,Location\n' +
          logs.map((log) => '${log.timestamp},${log.event},${log.location}').join('\n');
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/logs_${DateTime.now().toIso8601String()}.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Monthly Geofence Logs',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logs exported successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export logs: $e')),
        );
      }
    }
  }

  Future<void> updateSchedule(SchoolSchedule schedule) async {
    _schedule = schedule;
    await _dbService.saveSchedule(schedule);
  }

  Future<void> updateLocations(List<GeofenceLocation> locations) async {
    _locations = locations;
    await _dbService.saveLocations(locations);
  }
}