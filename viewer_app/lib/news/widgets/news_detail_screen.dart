import 'package:flutter/material.dart';

import '../news_item.dart';
import 'news_visuals.dart';

/// Noticia completa. El contenido en sí ([NewsDetailBody]) es el mismo
/// widget que muestra la vista previa del panel.
class NewsDetailScreen extends StatelessWidget {
  const NewsDetailScreen({super.key, required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    final hasImage = item.imageUrl != null;
    return Scaffold(
      // Con imagen, la barra va encima de la foto (transparente); sin
      // imagen, arriba del texto como una barra normal.
      extendBodyBehindAppBar: hasImage,
      appBar: AppBar(
        backgroundColor: hasImage ? Colors.transparent : null,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Material(
            color: Colors.black.withValues(alpha: hasImage ? 0.45 : 0),
            shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              tooltip: 'Volver',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: SafeArea(
          top: !hasImage,
          child: NewsDetailBody(
            item: item,
            image: hasImage ? NetworkImage(item.imageUrl!) : null,
          ),
        ),
      ),
    );
  }
}
