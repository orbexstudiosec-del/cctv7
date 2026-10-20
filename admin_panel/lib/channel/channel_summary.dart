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
    this.sources = const [],
    this.thumbnailUrl,
    this.startedAt,
    this.endedAt,
  });

  /// Puntos de transmisión adicionales, cada uno con sus días (ej. otro
  /// servidor el fin de semana). Los días sin servidor asignado usan
  /// [playbackUrl], el principal. Ver viewer_app/lib/channel/channel_summary.dart.
  final List<StreamSource> sources;

  /// El enlace que usan las apps en [now] (mismo criterio que la app).
  String? urlFor(DateTime now) {
    for (final s in sources) {
      if (s.url.isNotEmpty && s.days.contains(now.weekday)) return s.url;
    }
    if (hasPlaybackUrl) return playbackUrl;
    for (final s in sources) {
      if (s.url.isNotEmpty) return s.url;
    }
    return null;
  }

  /// Hay al menos un enlace para reproducir.
  bool get hasAnySource => urlFor(DateTime.now()) != null;

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
      sources: [
        for (final s in (data['sources'] as List? ?? const []))
          if (s is Map) StreamSource.fromMap(Map<String, dynamic>.from(s)),
      ],
      thumbnailUrl: data['thumbnailUrl'] as String?,
      startedAt: _toDate(data['startedAt']),
      endedAt: _toDate(data['endedAt']),
    );
  }

  static DateTime? _toDate(Object? value) =>
      value is Timestamp ? value.toDate() : null;
}

/// Un punto de transmisión adicional (servidor) con los días en que se usa.
/// Se guarda como elemento del array `sources` del doc del canal.
class StreamSource {
  const StreamSource({
    required this.id,
    required this.name,
    required this.url,
    required this.days,
  });

  final String id;
  final String name;
  final String url;

  /// 1 = lunes … 7 = domingo (igual que `DateTime.weekday`).
  final List<int> days;

  factory StreamSource.fromMap(Map<String, dynamic> data) => StreamSource(
        id: data['id'] as String? ?? '',
        name: data['name'] as String? ?? 'Servidor',
        url: (data['url'] as String? ?? '').trim(),
        days: [
          for (final d in (data['days'] as List? ?? const []))
            if (d is int && d >= 1 && d <= 7) d,
        ]..sort(),
      );

  Map<String, Object> toMap() =>
      {'id': id, 'name': name, 'url': url, 'days': days};
}
