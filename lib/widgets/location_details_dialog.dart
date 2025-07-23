import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/geofence_location.dart';

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
