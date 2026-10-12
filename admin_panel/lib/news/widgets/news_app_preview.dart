import 'package:flutter/material.dart';

import '../news_item.dart';
import 'news_visuals.dart';

/// Tema oscuro de la app de espectadores (copia de lo esencial de
/// viewer_app/lib/shared/theme.dart -> buildViewerTheme), para que la
/// vista previa se vea con los mismos colores que en el celular.
ThemeData viewerPreviewTheme(Color seed, Color? secondary) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    secondary: secondary,
    brightness: Brightness.dark,
  ).copyWith(surface: const Color(0xFF17171F));
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF0A0A0E),
  );
}

/// Marco de celular con el tema de la app adentro.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({
    super.key,
    required this.seed,
    required this.secondary,
    required this.child,
    this.height = 600,
  });

  final Color seed;
  final Color? secondary;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      height: height,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(38),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Theme(
          data: viewerPreviewTheme(seed, secondary),
          child: Builder(
            builder: (context) => ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: DefaultTextStyle(
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Encabezado "NOTICIAS" igual al de la app.
class NewsSectionHeader extends StatelessWidget {
  const NewsSectionHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(Icons.campaign_outlined, size: 15, color: color),
        const SizedBox(width: 8),
        Text(
          'NOTICIAS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// La sección de noticias tal como la arma la app (destacada arriba, resto
/// en lista) para una lista de noticias publicadas. Tocar una abre su
/// detalle dentro del mismo marco.
class NewsFeedPreview extends StatefulWidget {
  const NewsFeedPreview({super.key, required this.news});

  final List<NewsItem> news;

  @override
  State<NewsFeedPreview> createState() => _NewsFeedPreviewState();
}

class _NewsFeedPreviewState extends State<NewsFeedPreview> {
  NewsItem? _open;

  ImageProvider? _image(NewsItem item) =>
      item.imageUrl == null ? null : NetworkImage(item.imageUrl!);

  @override
  Widget build(BuildContext context) {
    final open = _open;
    if (open != null) {
      return NewsDetailPreview(
        item: open,
        image: _image(open),
        onBack: () => setState(() => _open = null),
      );
    }

    // Misma lógica que viewer_app/lib/news/widgets/news_section.dart.
    final news = widget.news.take(30).toList();
    final hero = news.where((n) => n.featured).firstOrNull;
    final rest = news.where((n) => n != hero).toList();

    if (news.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No hay noticias publicadas: en la app esta sección no aparece.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      children: [
        const NewsSectionHeader(),
        const SizedBox(height: 14),
        if (hero != null) ...[
          NewsHeroCard(
            item: hero,
            image: _image(hero),
            onTap: () => setState(() => _open = hero),
          ),
          const SizedBox(height: 14),
        ],
        for (final item in rest) ...[
          NewsListCard(
            item: item,
            image: _image(item),
            onTap: () => setState(() => _open = item),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Pantalla de detalle de la app, con su botón de volver.
class NewsDetailPreview extends StatelessWidget {
  const NewsDetailPreview({
    super.key,
    required this.item,
    required this.image,
    this.onBack,
  });

  final NewsItem item;
  final ImageProvider? image;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(top: image == null ? 56 : 0),
            child: NewsDetailBody(item: item, image: image),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: Material(
            color: Colors.black.withValues(alpha: image == null ? 0 : 0.45),
            shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: onBack,
            ),
          ),
        ),
      ],
    );
  }
}
