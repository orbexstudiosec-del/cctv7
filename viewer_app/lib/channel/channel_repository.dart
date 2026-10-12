import 'package:cloud_firestore/cloud_firestore.dart';

import 'channel_summary.dart';

/// Lectura (pública, sin auth) del único canal de un tenant. Ver
/// firestore.rules: `tenants/{tenantId}/streams/{streamId}` es de lectura
/// pública a propósito, para que esta app funcione sin cuenta de usuario.
/// El doc id es siempre "main" — ver admin_panel/lib/streams/stream_repository.dart.
class ChannelRepository {
  ChannelRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const _channelDocId = 'main';

  Stream<ChannelSummary?> watchChannel(String tenantId) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('streams')
        .doc(_channelDocId)
        .snapshots()
        .map(
          (snap) =>
              snap.exists ? ChannelSummary.fromFirestore(snap.data()!) : null,
        );
  }
}
