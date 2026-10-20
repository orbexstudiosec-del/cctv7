/// Un programa de la parrilla (doc `tenants/{tenantId}/schedule/{id}`).
/// Mismos campos lee viewer_app/lib/schedule/schedule_slot.dart.
///
/// Horas como texto "HH:mm" (legibles en la consola de Firebase). `end`
/// "00:00" = termina a medianoche.
class ScheduleSlot {
  const ScheduleSlot({
    required this.id,
    required this.title,
    required this.days,
    required this.start,
    required this.end,
    this.host = '',
    this.description = '',
  });

  final String id;
  final String title;
  final String host;
  final String description;

  /// 1 = lunes … 7 = domingo (igual que `DateTime.weekday`).
  final List<int> days;
  final String start;
  final String end;

  int get startMinutes => toMinutes(start);

  /// "00:00" como fin cuenta como 24:00 (medianoche).
  int get endMinutes {
    final m = toMinutes(end);
    return m == 0 ? 24 * 60 : m;
  }

  factory ScheduleSlot.fromFirestore(String id, Map<String, dynamic> data) {
    return ScheduleSlot(
      id: id,
      title: data['title'] as String? ?? '',
      host: data['host'] as String? ?? '',
      description: data['description'] as String? ?? '',
      days: [
        for (final d in (data['days'] as List? ?? const []))
          if (d is int && d >= 1 && d <= 7) d,
      ]..sort(),
      start: data['start'] as String? ?? '00:00',
      end: data['end'] as String? ?? '00:00',
    );
  }

  static int toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }
}

const kWeekdays = [
  'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
];
const kWeekdaysShort = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
