import 'package:flutter/material.dart';

import '../news_item.dart';
import '../news_repository.dart';
import 'news_detail_screen.dart';
import 'news_visuals.dart';

/// Noticias del tenant, pensada para ir debajo de la info del canal (en
/// vivo o fuera del aire). Arriba la destacada más reciente en grande, y
/// el resto en lista; tocar cualquiera abre el detalle. Si no hay
/// noticias muestra un aviso (va bajo la pestaña "Noticias").
class NewsSection extends StatelessWidget {
  const NewsSection({
    super.key,
    required this.tenantId,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 8),
  });

  final String tenantId;

  /// Margen alrededor de la sección; `EdgeInsets.zero` si el contenedor ya
  /// tiene el suyo.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NewsItem>>(
      stream: NewsRepository().watchNews(tenantId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // La sección se oculta igual (no tiene sentido mostrarle un error
          // técnico al espectador), pero que quede en el log.
          debugPrint('NewsSection: error cargando noticias: ${snapshot.error}');
        }
        final news = snapshot.data ?? const <NewsItem>[];
        if (news.isEmpty) {
          // Va debajo de la pestaña "Noticias": en vez de dejarla en blanco,
          // avisar (salvo mientras carga).
          if (!snapshot.hasData && !snapshot.hasError) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'Todavía no hay noticias publicadas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          );
        }

        final hero = news.where((n) => n.featured).firstOrNull;
        final rest = news.where((n) => n != hero).toList();

        void open(NewsItem item) => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => NewsDetailScreen(item: item),
              ),
            );

        return Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sin título "NOTICIAS": va debajo del selector
              // Noticias / Programación de la pantalla del canal.
              if (hero != null) ...[
                NewsHeroCard(
                  item: hero,
                  image: hero.imageUrl == null
                      ? null
                      : NetworkImage(hero.imageUrl!),
                  onTap: () => open(hero),
                ),
                const SizedBox(height: 14),
              ],
              for (final item in rest) ...[
                NewsListCard(
                  item: item,
                  image: item.imageUrl == null
                      ? null
                      : NetworkImage(item.imageUrl!),
                  onTap: () => open(item),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}
