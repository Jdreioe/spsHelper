class LogEntry {
  final int? id;
  final DateTime timestamp;
  final String event; // 'Enter' or 'Exit'
  final String location;

  LogEntry({
    this.id,
    required this.timestamp,
    required this.event,
    required this.location,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'event': event,
      'location': location,
    };
  }

  factory LogEntry.fromMap(Map<String, dynamic> map) {
    return LogEntry(
      id: map['id'],
      timestamp: DateTime.parse(map['timestamp']),
      event: map['event'],
      location: map['location'],
    );
  }
}