import 'package:cloud_firestore/cloud_firestore.dart';

/// El único canal de un tenant (doc fijo `tenants/{tenantId}/streams/main`).
/// Ya no es una lista de streams — un tenant = un canal (decisión del
/// 2026-10-10 de dejar el modelo SaaS multi-stream).
class ChannelSummary {
  const ChannelSummary({
    required this.title,
    required this.description,
    required this.status,
    this.playbackUrl,
    this.thumbnailUrl,
    this.startedAt,
    this.endedAt,
  });

  final String title;
  final String description;
  final String status; // live | offline

  /// Enlace de la señal (HLS) que entrega el proveedor de streaming del
  /// canal. Se pega desde el panel, ver ChannelRepository.setPlaybackUrl.
  final String? playbackUrl;
  final String? thumbnailUrl;
  final DateTime? startedAt;
  final DateTime? endedAt;

  bool get isLive => status == 'live';

  bool get hasPlaybackUrl => playbackUrl != null && playbackUrl!.isNotEmpty;

  factory ChannelSummary.fromFirestore(Map<String, dynamic> data) {
    return ChannelSummary(
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      status: data['status'] as String? ?? 'offline',
      playbackUrl: data['playbackUrl'] as String?,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      startedAt: _toDate(data['startedAt']),
      endedAt: _toDate(data['endedAt']),
    );
  }

  static DateTime? _toDate(Object? value) =>
      value is Timestamp ? value.toDate() : null;
}
