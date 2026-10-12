import 'package:flutter/material.dart';

import '../news_item.dart';
import '../news_repository.dart';
import 'news_detail_screen.dart';
import 'news_visuals.dart';

/// Noticias del tenant, pensada para ir debajo de la info del canal (en
/// vivo o fuera del aire). Arriba la destacada más reciente en grande, y
/// el resto en lista; tocar cualquiera abre el detalle. No se muestra nada
/// si no hay noticias, para no agregar una sección vacía.
class NewsSection extends StatelessWidget {
  const NewsSection({super.key, required this.tenantId});

  final String tenantId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<NewsItem>>(
      stream: NewsRepository().watchNews(tenantId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // La sección se oculta igual (no tiene sentido mostrarle un error
          // técnico al espectador), pero que quede en el log.
          debugPrint('NewsSection: error cargando noticias: ${snapshot.error}');
        }
        final news = snapshot.data ?? const <NewsItem>[];
        if (news.isEmpty) return const SizedBox.shrink();

        final hero = news.where((n) => n.featured).firstOrNull;
        final rest = news.where((n) => n != hero).toList();

        void open(NewsItem item) => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => NewsDetailScreen(item: item),
              ),
            );

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    size: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'NOTICIAS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
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
