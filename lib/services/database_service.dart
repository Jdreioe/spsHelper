import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/log_entry.dart';
import '../models/school_schedule.dart';
import '../models/geofence_location.dart';

class DatabaseService {
  Database? _database;

  Future<void> initialize() async {
    _database = await openDatabase(
      join(await getDatabasesPath(), 'geofence_logs.db'),
      onCreate: (db, version) {
        db.execute(
          'CREATE TABLE logs(id INTEGER PRIMARY KEY, timestamp TEXT, event TEXT, location TEXT)',
        );
        db.execute(
          'CREATE TABLE locations(dayOfWeek INTEGER, latitude REAL, longitude REAL, radius REAL, name TEXT)',
        );
        db.execute(
          'CREATE TABLE schedule(id INTEGER PRIMARY KEY, data TEXT)',
        );
      },
      version: 1,
    );
  }

  Future<void> insertLog(LogEntry entry) async {
    await _database?.insert('logs', entry.toMap());
  }

  Future<List<LogEntry>> getLogs() async {
    final List<Map<String, dynamic>> maps = await _database?.query('logs') ?? [];
    return List.generate(maps.length, (i) => LogEntry.fromMap(maps[i]));
  }

  Future<void> deleteLog(int id) async {
    await _database?.delete('logs', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> saveLocations(List<GeofenceLocation> locations) async {
    await _database?.delete('locations');
    for (var loc in locations) {
      await _database?.insert('locations', {
        'dayOfWeek': loc.dayOfWeek,
        'latitude': loc.latitude,
        'longitude': loc.longitude,
        'radius': loc.radius,
        'name': loc.name,
      });
    }
  }

  Future<List<GeofenceLocation>> getLocations() async {
    final List<Map<String, dynamic>> maps = await _database?.query('locations') ?? [];
    return maps.map((map) => GeofenceLocation(
          dayOfWeek: map['dayOfWeek'],
          latitude: map['latitude'],
          longitude: map['longitude'],
          radius: map['radius'],
          name: map['name'],
        )).toList();
  }

  Future<void> saveSchedule(SchoolSchedule schedule) async {
    await _database?.delete('schedule');
    await _database?.insert('schedule', {
      'id': 1,
      'data': jsonEncode(schedule.toMap()), // <-- Use JSON encoding
    });
  }

  Future<SchoolSchedule?> getSchedule() async {
    final List<Map<String, dynamic>> maps = await _database?.query('schedule') ?? [];
    if (maps.isEmpty) return null;
    final data = jsonDecode(maps.first['data']);
    return SchoolSchedule.fromMap(data);
  }

}