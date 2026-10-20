import 'package:cloud_firestore/cloud_firestore.dart';

/// Un programa de la parrilla (doc `tenants/{tenantId}/schedule/{id}`),
/// cargado desde el panel. Mismos campos que
/// admin_panel/lib/schedule/schedule_slot.dart. Lectura pública, ver
/// firestore.rules.
///
/// Horas como texto "HH:mm"; `end` "00:00" = termina a medianoche.
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

  int get startMinutes => _toMinutes(start);

  int get endMinutes {
    final m = _toMinutes(end);
    return m == 0 ? 24 * 60 : m;
  }

  /// ¿Está al aire en [now]?
  bool isOnAir(DateTime now) {
    if (!days.contains(now.weekday)) return false;
    final m = now.hour * 60 + now.minute;
    return m >= startMinutes && m < endMinutes;
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
      ],
      start: data['start'] as String? ?? '00:00',
      end: data['end'] as String? ?? '00:00',
    );
  }

  static int _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  /// Toda la parrilla del tenant, ordenada por hora de inicio.
  static Stream<List<ScheduleSlot>> watch(String tenantId) {
    return FirebaseFirestore.instance
        .collection('tenants')
        .doc(tenantId)
        .collection('schedule')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ScheduleSlot.fromFirestore(d.id, d.data()))
            .toList()
          ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes)));
  }
}

const kWeekdays = [
  'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
];
const kWeekdaysShort = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
