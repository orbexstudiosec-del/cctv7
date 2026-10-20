import 'package:cloud_firestore/cloud_firestore.dart';

import 'schedule_slot.dart';

/// CRUD de la parrilla de programación de un tenant. Ver firestore.rules
/// (`tenants/{tenantId}/schedule`): lectura pública, escribe el staff.
class ScheduleRepository {
  ScheduleRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _schedule(String tenantId) =>
      _firestore.collection('tenants').doc(tenantId).collection('schedule');

  /// Todos los programas, ordenados por hora de inicio.
  Stream<List<ScheduleSlot>> watch(String tenantId) {
    return _schedule(tenantId).snapshots().map((snap) {
      final slots = snap.docs
          .map((d) => ScheduleSlot.fromFirestore(d.id, d.data()))
          .toList()
        ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
      return slots;
    });
  }

  /// Crea o actualiza. [existing] nulo = crear.
  Future<void> save(
    String tenantId, {
    ScheduleSlot? existing,
    required String title,
    required String host,
    required String description,
    required List<int> days,
    required String start,
    required String end,
  }) async {
    final data = <String, Object?>{
      'title': title,
      'host': host,
      'description': description,
      'days': days..sort(),
      'start': start,
      'end': end,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (existing != null) {
      await _schedule(tenantId).doc(existing.id).update(data);
    } else {
      data['createdAt'] = FieldValue.serverTimestamp();
      await _schedule(tenantId).add(data);
    }
  }

  Future<void> delete(String tenantId, String id) =>
      _schedule(tenantId).doc(id).delete();
}
