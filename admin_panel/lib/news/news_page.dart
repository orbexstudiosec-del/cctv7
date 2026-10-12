import 'package:flutter/material.dart';

import '../shared/theme.dart';
import 'news_item.dart';
import 'news_repository.dart';
import 'widgets/news_app_preview.dart';
import 'widgets/news_form_dialog.dart';
import 'widgets/news_visuals.dart';

enum _Filter { all, published, drafts, featured }

/// Noticias del tenant: filtros, tarjetas con la misma pinta que en la app
/// y acciones rápidas. `editor`/`tenant_admin` gestionan, `tenant_admin`
/// borra (igual que firestore.rules).
class NewsPage extends StatefulWidget {
  const NewsPage({
    super.key,
    required this.tenantId,
    required this.search,
    required this.canManage,
    required this.canDelete,
    required this.brandColor,
    required this.brandSecondary,
  });

  final String tenantId;
  final String search;
  final bool canManage;
  final bool canDelete;
  final Color brandColor;
  final Color? brandSecondary;

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  final _repository = NewsRepository();
  late final _stream = _repository.watchNews(widget.tenantId);
  _Filter _filter = _Filter.all;

  bool _matches(NewsItem n) {
    final q = widget.search.trim().toLowerCase();
    if (q.isEmpty) return true;
    return n.title.toLowerCase().contains(q) ||
        n.summary.toLowerCase().contains(q) ||
        n.body.toLowerCase().contains(q) ||
        (n.category?.toLowerCase().contains(q) ?? false);
  }

  bool _inFilter(NewsItem n) => switch (_filter) {
        _Filter.all => true,
        _Filter.published => n.published,
        _Filter.drafts => !n.published,
        _Filter.featured => n.featured,
      };

  void _edit(NewsItem item) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => NewsFormDialog(
          tenantId: widget.tenantId,
          repository: _repository,
          brandColor: widget.brandColor,
          brandSecondary: widget.brandSecondary,
          existing: item,
        ),
      );

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo: $e')));
      }
    }
  }

  Future<void> _confirmDelete(NewsItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar noticia'),
        content: Text(
            '¿Seguro que querés eliminar "${item.title}"? También se borra '
            'su imagen. No se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(() => _repository.delete(widget.tenantId, item),
          'Noticia eliminada.');
    }
  }

  void _showAppPreview(List<NewsItem> news) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhoneFrame(
              seed: widget.brandColor,
              secondary: widget.brandSecondary,
              height: (MediaQuery.sizeOf(context).height - 140)
                  .clamp(420.0, 720.0),
              child: NewsFeedPreview(
                  news: news.where((n) => n.published).toList()),
            ),
            const SizedBox(height: 14),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NewsItem>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = snapshot.data ?? const <NewsItem>[];
        final searched = all.where(_matches).toList();
        final visible = searched.where(_inFilter).toList();
        // La que la app muestra grande: la destacada publicada más reciente.
        final heroId =
            all.where((n) => n.published && n.featured).firstOrNull?.id;

        int count(_Filter f) {
          final prev = _filter;
          _filter = f;
          final c = searched.where(_inFilter).length;
          _filter = prev;
          return c;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final (f, label) in [
                              (_Filter.all, 'Todas'),
                              (_Filter.published, 'Publicadas'),
                              (_Filter.drafts, 'Borradores'),
                              (_Filter.featured, 'Destacadas'),
                            ])
                              FilterChip(
                                label: Text('$label · ${count(f)}'),
                                selected: _filter == f,
                                showCheckmark: false,
                                onSelected: (_) => setState(() => _filter = f),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => _showAppPreview(all),
                        icon: const Icon(Icons.phone_android_rounded, size: 18),
                        label: const Text('Ver como en la app'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (visible.isEmpty)
                    _EmptyState(
                      message: all.isEmpty
                          ? 'Todavía no hay noticias. Creá la primera con '
                              '"Nueva noticia".'
                          : 'No hay noticias que coincidan.',
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 1000
                            ? 3
                            : constraints.maxWidth >= 640
                                ? 2
                                : 1;
                        const gap = 16.0;
                        final width =
                            (constraints.maxWidth - gap * (columns - 1)) /
                                columns;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final item in visible)
                              SizedBox(
                                width: width,
                                child: _NewsAdminCard(
                                  item: item,
                                  isHero: item.id == heroId,
                                  canManage: widget.canManage,
                                  canDelete: widget.canDelete,
                                  onEdit: () => _edit(item),
                                  onToggleFeatured: () => _run(
                                    () => _repository.setFeatured(
                                        widget.tenantId,
                                        item.id,
                                        !item.featured),
                                    item.featured
                                        ? 'Ya no está destacada.'
                                        : 'Marcada como destacada.',
                                  ),
                                  onTogglePublished: () => _run(
                                    () => _repository.setPublished(
                                        widget.tenantId,
                                        item.id,
                                        !item.published),
                                    item.published
                                        ? 'Pasó a borrador: ya no se ve en la app.'
                                        : 'Publicada: ya se ve en la app.',
                                  ),
                                  onDelete: () => _confirmDelete(item),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NewsAdminCard extends StatelessWidget {
  const _NewsAdminCard({
    required this.item,
    required this.isHero,
    required this.canManage,
    required this.canDelete,
    required this.onEdit,
    required this.onToggleFeatured,
    required this.onTogglePublished,
    required this.onDelete,
  });

  final NewsItem item;
  final bool isHero;
  final bool canManage;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onToggleFeatured;
  final VoidCallback onTogglePublished;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final teaser = newsTeaser(item);

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canManage ? onEdit : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isHero
                  ? Colors.amber.withValues(alpha: 0.7)
                  : scheme.outlineVariant.withValues(alpha: 0.6),
              width: isHero ? 1.6 : 1,
            ),
            boxShadow: floatingShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (item.imageUrl != null)
                      NewsImage(image: NetworkImage(item.imageUrl!))
                    else
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              newsCategoryColor(context, item.category),
                              const Color(0xFF0A0A12),
                            ],
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.article_outlined,
                              color: Colors.white54, size: 32),
                        ),
                      ),
                    // Borradores atenuados: a simple vista se nota qué no
                    // está en la app.
                    if (!item.published)
                      ColoredBox(color: Colors.white.withValues(alpha: 0.45)),
                    Positioned(
                      top: 10,
                      left: 10,
                      right: 10,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (!item.published)
                            const _Badge(
                              icon: Icons.edit_note_rounded,
                              label: 'BORRADOR',
                              color: Color(0xFF52525B),
                            ),
                          if (isHero)
                            const _Badge(
                              icon: Icons.star_rounded,
                              label: 'EN PORTADA',
                              color: Color(0xFFB45309),
                            )
                          else if (item.featured)
                            const _Badge(
                              icon: Icons.star_outline_rounded,
                              label: 'DESTACADA',
                              color: Color(0xFFB45309),
                            ),
                          if (item.category != null)
                            NewsCategoryChip(
                                category: item.category!, solid: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title.isEmpty ? '(sin título)' : item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700, height: 1.25),
                    ),
                    if (teaser.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        teaser,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      _dateLine(item),
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (canManage)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: item.featured
                            ? 'Quitar de destacadas'
                            : 'Destacar (portada de la app)',
                        onPressed: onToggleFeatured,
                        icon: Icon(
                          item.featured
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: item.featured ? Colors.amber.shade700 : null,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: onTogglePublished,
                        icon: Icon(
                          item.published
                              ? Icons.visibility_off_outlined
                              : Icons.send_rounded,
                          size: 17,
                        ),
                        label:
                            Text(item.published ? 'Despublicar' : 'Publicar'),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Editar',
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 20),
                      ),
                      if (canDelete)
                        IconButton(
                          tooltip: 'Eliminar',
                          onPressed: onDelete,
                          icon: Icon(Icons.delete_outline_rounded,
                              size: 20, color: scheme.error),
                        ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  String _dateLine(NewsItem item) {
    if (item.createdAt == null) return 'Guardando…';
    final created = newsRelativeDate(item.createdAt);
    final edited = item.updatedAt != null &&
        item.updatedAt!.difference(item.createdAt!).inMinutes >= 5;
    return edited
        ? '$created · editada ${newsRelativeDate(item.updatedAt).toLowerCase()}'
        : created;
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.campaign_outlined,
                size: 26, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
