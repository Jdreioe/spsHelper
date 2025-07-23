import 'package:flutter/material.dart';
import '../models/school_schedule.dart';

class SchedulePickerDialog extends StatefulWidget {
  final SchoolSchedule? schedule;
  const SchedulePickerDialog({super.key, this.schedule});

  @override
  _SchedulePickerDialogState createState() => _SchedulePickerDialogState();
}

class _SchedulePickerDialogState extends State<SchedulePickerDialog> {
  late Map<int, List<TimeRange>> _weeklySchedule;

  @override
  void initState() {
    super.initState();
    _weeklySchedule = widget.schedule?.weeklySchedule.map(
          (key, value) => MapEntry(key, List<TimeRange>.from(value)),
        ) ??
        {};
  }

  Future<void> _addTimeRange(int day) async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (start == null) return;
    final end = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 16, minute: 0),
    );
    if (end == null) return;
    setState(() {
      _weeklySchedule[day] = _weeklySchedule[day] ?? [];
      _weeklySchedule[day]!.add(TimeRange(start: start, end: end));
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Vælg skema'),
      content: SingleChildScrollView(
        child: Column(
          children: List.generate(5, (index) {
            final day = index + 1;
            final dayName = ['Mandag', 'Tirsdag', 'Onsdag', 'Torsdag', 'Fredag'][index];
            return ExpansionTile(
              title: Text(dayName),
              children: [
                ...(_weeklySchedule[day] ?? []).asMap().entries.map((entry) {
                  final range = entry.value;
                  return ListTile(
                    title: Text('${range.start.format(context)} - ${range.end.format(context)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          _weeklySchedule[day]!.removeAt(entry.key);
                          if (_weeklySchedule[day]!.isEmpty) _weeklySchedule.remove(day);
                        });
                      },
                    ),
                  );
                }),
                TextButton(
                  onPressed: () => _addTimeRange(day),
                  child: const Text('Tilføj tidsrum'),
                ),
              ],
            );
          }),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            SchoolSchedule(weeklySchedule: _weeklySchedule, isActive: true),
          ),
          child: const Text('Gem'),
        ),
      ],
    );
  }
}
