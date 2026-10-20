// IMPORTANTE: este archivo existe IDÉNTICO en dos lugares:
//   viewer_app/lib/news/widgets/news_visuals.dart   (lo que ve el espectador)
//   admin_panel/lib/news/widgets/news_visuals.dart  (vista previa del panel)
// para que la vista previa del panel sea exactamente la app. Si cambiás uno,
// copiá el otro. Solo depende de `news_item.dart` (mismos campos en ambos
// proyectos) y de Flutter.
import 'package:flutter/material.dart';

import '../../shared/theme.dart';
import '../news_item.dart';

/// Color de cada categoría (las mismas de `kNewsCategories`). Sin
/// categoría -> color primario de la marca.
Color newsCategoryColor(BuildContext context, String? category) {
  return switch (category) {
    'Local' => const Color(0xFF3B82F6),
    'Nacional' => const Color(0xFF6366F1),
    'Deportes' => const Color(0xFF22C55E),
    'Cultura' => const Color(0xFFA855F7),
    'Comunicados' => const Color(0xFFF59E0B),
    'Programación' => const Color(0xFF14B8A6),
    _ => Theme.of(context).colorScheme.primary,
  };
}

const _months = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
  'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// "hace 5 min", "hace 2 h", "ayer", "hace 3 días", "12 oct".
String newsRelativeDate(DateTime? date, {DateTime? now}) {
  if (date == null) return 'Ahora';
  final current = now ?? DateTime.now();
  final diff = current.difference(date);
  if (diff.inMinutes < 1) return 'Hace un momento';
  if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
  if (diff.inDays == 1) return 'Ayer';
  if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
  final month = _months[date.month - 1].substring(0, 3);
  return date.year == current.year
      ? '${date.day} $month'
      : '${date.day} $month ${date.year}';
}

/// "11 de octubre de 2026 · 14:30"
String newsFullDate(DateTime date) {
  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');
  return '${date.day} de ${_months[date.month - 1]} de ${date.year} · $hh:$mm';
}

/// Texto corto de la tarjeta: la bajada si hay, si no el comienzo del
/// cuerpo.
String newsTeaser(NewsItem item) {
  final text = item.summary.trim().isNotEmpty ? item.summary : item.body;
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Imagen de red/memoria con fondo mientras carga y sin romper si falla.
class NewsImage extends StatelessWidget {
  const NewsImage({super.key, required this.image, this.fit = BoxFit.cover});

  final ImageProvider image;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Colors.white.withValues(alpha: 0.06),
      child: Center(
        child: Icon(Icons.image_outlined,
            color: Colors.white.withValues(alpha: 0.25), size: 28),
      ),
    );
    return Image(
      image: image,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSync) {
        if (wasSync || frame != null) return child;
        return placeholder;
      },
      errorBuilder: (context, error, stack) => placeholder,
    );
  }
}

class NewsCategoryChip extends StatelessWidget {
  const NewsCategoryChip({super.key, required this.category, this.solid = false});

  final String category;

  /// Fondo lleno (sobre fotos) en vez de tinte suave.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final color = newsCategoryColor(context, category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category.toUpperCase(),
        style: TextStyle(
          color: solid ? Colors.white : color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Noticia destacada: imagen grande con el título encima.
class NewsHeroCard extends StatelessWidget {
  const NewsHeroCard({
    super.key,
    required this.item,
    required this.image,
    this.onTap,
    this.now,
  });

  final NewsItem item;
  final ImageProvider? image;
  final VoidCallback? onTap;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: scheme.surface,
        child: InkWell(
          onTap: onTap,
          child: AspectRatio(
            aspectRatio: 16 / 11,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (image != null)
                  NewsImage(image: image!)
                else
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          newsCategoryColor(context, item.category),
                          kAppBackground,
                        ],
                      ),
                    ),
                  ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.25, 1],
                      colors: [Colors.transparent, Color(0xE6000000)],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded,
                                    size: 12, color: Colors.black),
                                SizedBox(width: 3),
                                Text(
                                  'DESTACADA',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (item.category != null) ...[
                            const SizedBox(width: 6),
                            NewsCategoryChip(
                                category: item.category!, solid: true),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.title.isEmpty ? 'Título de la noticia' : item.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        newsRelativeDate(item.createdAt, now: now),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Noticia en la lista: miniatura a la izquierda, texto a la derecha.
class NewsListCard extends StatelessWidget {
  const NewsListCard({
    super.key,
    required this.item,
    required this.image,
    this.onTap,
    this.now,
  });

  final NewsItem item;
  final ImageProvider? image;
  final VoidCallback? onTap;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final teaser = newsTeaser(item);
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (image != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 104,
                    height: 80,
                    child: NewsImage(image: image!),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (item.category != null) ...[
                          NewsCategoryChip(category: item.category!),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            newsRelativeDate(item.createdAt, now: now),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant
                                  .withValues(alpha: 0.8),
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title.isEmpty ? 'Título de la noticia' : item.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (teaser.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        teaser,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Contenido completo de la noticia (pantalla de detalle).
class NewsDetailBody extends StatelessWidget {
  const NewsDetailBody({super.key, required this.item, required this.image});

  final NewsItem item;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final paragraphs = item.body
        .split(RegExp(r'\n\s*\n|\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final edited = item.updatedAt != null &&
        item.createdAt != null &&
        item.updatedAt!.difference(item.createdAt!).inMinutes >= 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (image != null)
          AspectRatio(aspectRatio: 16 / 9, child: NewsImage(image: image!)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.category != null) ...[
                NewsCategoryChip(category: item.category!),
                const SizedBox(height: 12),
              ],
              SelectableText(
                item.title.isEmpty ? 'Título de la noticia' : item.title,
                style: const TextStyle(
                  fontSize: 24,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      item.createdAt == null
                          ? 'Recién publicada'
                          : newsFullDate(item.createdAt!) +
                              (edited ? ' · editada' : ''),
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              if (item.summary.trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: newsCategoryColor(context, item.category),
                        width: 3,
                      ),
                    ),
                  ),
                  child: SelectableText(
                    item.summary.trim(),
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              for (final p in paragraphs) ...[
                SelectableText(
                  p,
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.6,
                    color: scheme.onSurface.withValues(alpha: 0.88),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
