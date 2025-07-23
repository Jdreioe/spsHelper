import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'screens/settings_screen.dart';
import 'screens/log_screen.dart';
import 'services/geofence_service.dart';
import 'services/notification_service.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initialize();
  await FMTCObjectBoxBackend().initialise();
  await FMTCStore('mapStore').manage.create();
  
  runApp(const GeofenceApp());
}

class GeofenceApp extends StatelessWidget {
  const GeofenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SPS-helper Alpha 0.1',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      navigatorObservers: [routeObserver],
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GeofenceService _geofenceService = GeofenceService();
  late final Future<void> _initializationFuture;

  @override
  void initState() {
    super.initState();
    _initializationFuture = _geofenceService.initialize();
  }

  @override
  void dispose() {
    _geofenceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SPS-registrerings hjælp Alpha 0.1')),
      body: FutureBuilder(
        future: _initializationFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error initializing: ${snapshot.error}'));
          }
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  child: const Text('Indstillinger'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LogScreen()),
                  ),
                  child: const Text('Se logs'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    _geofenceService.logEvent('Test', 'Button Click');
                    print('--- Log Created: Test, Button Click ---');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Test log created!')),
                    );
                  },
                  child: const Text('Test Log'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}