import 'package:cloud_firestore/cloud_firestore.dart';

/// El único canal de un tenant (ya no es una lista de streams — un tenant
/// = un canal, ver decisión del 2026-10-10 de dejar el modelo SaaS
/// multi-stream). Vive en `tenants/{tenantId}/streams/main`.
///
/// La señal puede venir de varios puntos de transmisión (servidores) que
/// el canal carga en el panel: `playbackUrl` es el **principal** y
/// `sources` son los adicionales, cada uno con los días en que se usa
/// (ej. un servidor de lunes a viernes y otro el fin de semana). La app
/// arranca con el del día ([sourceFor]) y el espectador puede elegir otro.
class ChannelSummary {
  const ChannelSummary({
    required this.title,
    required this.description,
    required this.status,
    this.playbackUrl,
    this.sources = const [],
    this.thumbnailUrl,
    this.startedAt,
  });

  final String title;
  final String description;
  final String status; // live | offline
  final String? playbackUrl;
  final List<StreamSource> sources;
  final String? thumbnailUrl;
  final DateTime? startedAt;

  bool get isLive => status == 'live';

  /// Todos los puntos de transmisión que se pueden elegir: el principal
  /// primero, después los adicionales.
  List<StreamSource> get options => [
        if (playbackUrl != null && playbackUrl!.isNotEmpty)
          StreamSource(
            id: StreamSource.principalId,
            name: 'Principal',
            url: playbackUrl!,
            days: const [],
          ),
        ...sources.where((s) => s.url.isNotEmpty),
      ];

  bool get hasPlayback => options.isNotEmpty;

  /// El que toca usar en [now]: el primer servidor adicional asignado a
  /// ese día; si ninguno, el principal; si no hay principal, el primero.
  StreamSource? sourceFor(DateTime now) {
    final all = options;
    if (all.isEmpty) return null;
    return sources.where((s) => s.url.isNotEmpty).firstWhere(
          (s) => s.days.contains(now.weekday),
          orElse: () => all.first,
        );
  }

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
      startedAt: data['startedAt'] is Timestamp
          ? (data['startedAt'] as Timestamp).toDate()
          : null,
    );
  }
}

/// Un punto de transmisión (servidor) del canal. Mismos campos que
/// admin_panel/lib/channel/channel_summary.dart.
class StreamSource {
  const StreamSource({
    required this.id,
    required this.name,
    required this.url,
    required this.days,
  });

  static const principalId = 'principal';

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
        ],
      );
}
