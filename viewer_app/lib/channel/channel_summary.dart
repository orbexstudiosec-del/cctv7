import 'package:cloud_firestore/cloud_firestore.dart';

/// El único canal de un tenant (ya no es una lista de streams — un tenant
/// = un canal, ver decisión del 2026-10-10 de dejar el modelo SaaS
/// multi-stream). Vive en `tenants/{tenantId}/streams/main`;
/// `playbackUrl` es el enlace de la señal que el canal pega en el panel.
class ChannelSummary {
  const ChannelSummary({
    required this.title,
    required this.description,
    required this.status,
    this.playbackUrl,
    this.thumbnailUrl,
    this.startedAt,
  });

  final String title;
  final String description;
  final String status; // live | offline
  final String? playbackUrl;
  final String? thumbnailUrl;
  final DateTime? startedAt;

  bool get isLive => status == 'live';

  factory ChannelSummary.fromFirestore(Map<String, dynamic> data) {
    return ChannelSummary(
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      status: data['status'] as String? ?? 'offline',
      playbackUrl: data['playbackUrl'] as String?,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      startedAt: data['startedAt'] is Timestamp
          ? (data['startedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
