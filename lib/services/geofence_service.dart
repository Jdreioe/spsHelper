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
  final DatabaseService _dbService = DatabaseService();
  List<GeofenceLocation> _locations = [];
  SchoolSchedule? _schedule;
  bool _isMonitoring = false;

  // Public getters
  SchoolSchedule? get schedule => _schedule;
  List<GeofenceLocation> get locations => _locations;

  Future<void> initialize() async {
    await _dbService.initialize();
    await _requestPermissions();
    await _loadLocations();
    await _loadSchedule();
    if (!_isMonitoring) {
      _startGeofenceMonitoring();
    }
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
    if (_locations.isEmpty) {
      _locations = [
        GeofenceLocation(
          dayOfWeek: 1,
          latitude: 59.9399,
          longitude: 10.7215,
          radius: 100,
          name: 'University',
        ),
      ];
    }
  }

  Future<void> _loadSchedule() async {
    _schedule = await _dbService.getSchedule();
    if (_schedule == null) {
      _schedule = SchoolSchedule(weeklySchedule: {}, isActive: true);
    }
  }

  void _startGeofenceMonitoring() {
    _isMonitoring = true;
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      final todayLocations = _locations.where((loc) => loc.dayOfWeek == DateTime.now().weekday).toList();
      for (var loc in todayLocations) {
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          loc.latitude,
          loc.longitude,
        );
        if (distance <= loc.radius && _isWithinSchedule()) {
          _logEvent('Enter', loc.name);
        } else if (distance > loc.radius) {
          _logEvent('Exit', loc.name);
        }
      }
    });
  }

  bool _isWithinSchedule() {
    if (_schedule == null || !_schedule!.isActive) return true;
    final now = DateTime.now();
    final todaySchedule = _schedule!.weeklySchedule[now.weekday] ?? [];
    final currentTime = TimeOfDay.fromDateTime(now);
    return todaySchedule.any((range) =>
        _compareTimeOfDay(currentTime, range.start) >= 0 &&
        _compareTimeOfDay(currentTime, range.end) <= 0);
  }

  int _compareTimeOfDay(TimeOfDay t1, TimeOfDay t2) {
    final t1Minutes = t1.hour * 60 + t1.minute;
    final t2Minutes = t2.hour * 60 + t2.minute;
    return t1Minutes.compareTo(t2Minutes);
  }

  Future<void> _logEvent(String event, String location) async {
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