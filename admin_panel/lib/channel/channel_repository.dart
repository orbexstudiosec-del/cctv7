import 'package:cloud_firestore/cloud_firestore.dart';

import 'channel_summary.dart';

/// El canal de un tenant vive en un único doc de id fijo "main" dentro de
/// `tenants/{tenantId}/streams` (se mantiene ese nombre de colección por
/// compatibilidad con firestore.rules y viewer_app, aunque ya no hay una
/// lista real de streams — ver docs/ARCHITECTURE.md).
class ChannelRepository {
  ChannelRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const channelDocId = 'main';

  DocumentReference<Map<String, dynamic>> _channelDoc(String tenantId) =>
      _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('streams')
          .doc(channelDocId);

  Stream<ChannelSummary?> watchChannel(String tenantId) {
    return _channelDoc(tenantId).snapshots().map(
          (snap) =>
              snap.exists ? ChannelSummary.fromFirestore(snap.data()!) : null,
        );
  }

  /// Crea el doc del canal si todavía no existe (primera vez que se abre
  /// el panel). No pisa nada si ya existe.
  Future<void> ensureChannel(String tenantId) async {
    final snap = await _channelDoc(tenantId).get();
    if (snap.exists) return;
    await _channelDoc(tenantId).set({
      'title': '',
      'description': '',
      'status': 'offline',
      'playbackUrl': null,
      'thumbnailUrl': null,
      'startedAt': null,
      'endedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateDetails(
    String tenantId, {
    required String title,
    required String description,
  }) {
    return _channelDoc(tenantId).update({
      'title': title,
      'description': description,
    });
  }

  /// Transición válida: live <-> offline. Sella el timestamp
  /// correspondiente al entrar a cada estado. Acá no hay servidor propio
  /// que avise si la señal está arriba o no: este estado es el único
  /// interruptor, y las apps solo reproducen mientras esté en `live`.
  Future<void> setLive(String tenantId, bool live) {
    final update = <String, Object?>{'status': live ? 'live' : 'offline'};
    if (live) {
      update['startedAt'] = FieldValue.serverTimestamp();
    } else {
      update['endedAt'] = FieldValue.serverTimestamp();
    }
    return _channelDoc(tenantId).update(update);
  }

  /// Guarda el enlace de la señal (el .m3u8 que entrega el proveedor de
  /// streaming del canal): es lo que reproducen las apps y la vista previa
  /// del panel. `null` lo quita.
  Future<void> setPlaybackUrl(String tenantId, String? url) {
    return _channelDoc(tenantId).update({'playbackUrl': url});
  }
}
