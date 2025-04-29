class GeofenceLocation {
  final int dayOfWeek; // 1 = Monday, 7 = Sunday
  final double latitude;
  final double longitude;
  final double radius; // in meters
  final String name;

  GeofenceLocation({
    required this.dayOfWeek,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.name,
  });
}