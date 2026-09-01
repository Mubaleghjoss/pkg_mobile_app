/// Event kalender read-only yang sudah dinormalisasi ke zona waktu perangkat.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    required this.type,
    required this.color,
    required this.details,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    final rawEnd = json['end'];
    return CalendarEvent(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      start: DateTime.parse('${json['start']}').toLocal(),
      end: rawEnd == null ? null : DateTime.parse('$rawEnd').toLocal(),
      allDay: json['all_day'] == true,
      type: '${json['type'] ?? 'lainnya'}',
      color: '${json['color'] ?? '#607D8B'}',
      details:
          (json['details'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
  }

  final String id;
  final String title;
  final DateTime start;
  final DateTime? end;
  final bool allDay;
  final String type;
  final String color;
  final Map<String, dynamic> details;
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

Map<DateTime, List<CalendarEvent>> groupCalendarEvents(
  Iterable<CalendarEvent> events,
) {
  final grouped = <DateTime, List<CalendarEvent>>{};
  for (final event in events) {
    grouped
        .putIfAbsent(dateOnly(event.start), () => <CalendarEvent>[])
        .add(event);
  }
  return grouped;
}
