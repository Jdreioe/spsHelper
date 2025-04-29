import 'package:flutter/material.dart';
import '../services/geofence_service.dart';
import '../models/log_entry.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  _LogScreenState createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final GeofenceService _geofenceService = GeofenceService();
  List<LogEntry> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await _geofenceService.getLogs();
    setState(() {
      _logs = logs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _geofenceService.exportLogs(context),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _logs.length,
        itemBuilder: (context, index) {
          final log = _logs[index];
          return ListTile(
            title: Text('${log.event} at ${log.location}'),
            subtitle: Text(log.timestamp.toString()),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                await _geofenceService.deleteLog(log.id!);
                _loadLogs();
              },
            ),
          );
        },
      ),
    );
  }
}