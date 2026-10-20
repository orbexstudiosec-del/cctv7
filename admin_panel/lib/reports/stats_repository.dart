import 'package:cloud_firestore/cloud_firestore.dart';

import 'daily_stats.dart';

/// Lee los contadores diarios que escribe la app (ver firestore.rules,
/// `tenants/{tenantId}/stats/{day}`).
class StatsRepository {
  StatsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Un [DailyStats] por día de [from] a [to] (ambos incluidos), en orden;
  /// los días sin visitas vienen en 0 para que el reporte no tenga huecos.
  Future<List<DailyStats>> fetchRange(
    String tenantId,
    DateTime from,
    DateTime to,
  ) async {
    final snap = await _firestore
        .collection('tenants/$tenantId/stats')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: dayKey(from))
        .where(FieldPath.documentId, isLessThanOrEqualTo: dayKey(to))
        .get();
    final byDay = {for (final doc in snap.docs) doc.id: doc.data()};

    final days = <DailyStats>[];
    for (var d = DateTime(from.year, from.month, from.day);
        !d.isAfter(to);
        d = DateTime(d.year, d.month, d.day + 1)) {
      final data = byDay[dayKey(d)];
      days.add(data == null
          ? DailyStats(day: d)
          : DailyStats.fromFirestore(d, data));
    }
    return days;
  }
}
