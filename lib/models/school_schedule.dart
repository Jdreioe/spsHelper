import 'package:flutter/material.dart';

class TimeRange {
  final TimeOfDay start;
  final TimeOfDay end;

  TimeRange({required this.start, required this.end});

  Map<String, dynamic> toMap() {
    return {
      'startHour': start.hour,
      'startMinute': start.minute,
      'endHour': end.hour,
      'endMinute': end.minute,
    };
  }

  factory TimeRange.fromMap(Map<String, dynamic> map) {
    return TimeRange(
      start: TimeOfDay(hour: map['startHour'], minute: map['startMinute']),
      end: TimeOfDay(hour: map['endHour'], minute: map['endMinute']),
    );
  }
}

class SchoolSchedule {
  final Map<int, List<TimeRange>> weeklySchedule;
  final bool isActive;

  SchoolSchedule({required this.weeklySchedule, required this.isActive});

  Map<String, dynamic> toMap() {
    return {
      'weeklySchedule': weeklySchedule.map((day, ranges) => MapEntry(
            day.toString(),
            ranges.map((range) => range.toMap()).toList(),
          )),
      'isActive': isActive,
    };
  }

  factory SchoolSchedule.fromMap(Map<String, dynamic> map) {
    return SchoolSchedule(
      weeklySchedule: (map['weeklySchedule'] as Map<String, dynamic>).map(
        (day, ranges) => MapEntry(
          int.parse(day),
          (ranges as List<dynamic>)
              .map((range) => TimeRange.fromMap(range))
              .toList(),
        ),
      ),
      isActive: map['isActive'],
    );
  }
}