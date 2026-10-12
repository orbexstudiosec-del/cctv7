import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../news_item.dart';
import '../news_repository.dart';
import 'news_app_preview.dart';
import 'news_visuals.dart';

/// Alta/edición de una noticia, con vista previa en vivo a la derecha que
/// usa los MISMOS widgets que la app (news_visuals.dart): lo que se ve acá
/// es lo que va a ver el espectador.
class NewsFormDialog extends StatefulWidget {
  const NewsFormDialog({
    super.key,
    required this.tenantId,
    required this.repository,
    required this.brandColor,
    required this.brandSecondary,
    this.existing,
  });

  final String tenantId;
  final NewsRepository repository;
  final Color brandColor;
  final Color? brandSecondary;

  /// Si se pasa, el diálogo edita esta noticia en vez de crear una nueva.
  final NewsItem? existing;

  @override
  State<NewsFormDialog> createState() => _NewsFormDialogState();
}

enum _PreviewMode { card, detail }

class _NewsFormDialogState extends State<NewsFormDialog> {
  static const _titleMax = 120;
  static const _summaryMax = 220;

  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _summary = TextEditingController(text: widget.existing?.summary);
  late final _body = TextEditingController(text: widget.existing?.body);
  late String? _category = widget.existing?.category;
  late bool _featured = widget.existing?.featured ?? false;

  Uint8List? _pickedImage;
  late bool _removeImage = false;
  bool _saving = false;
  String? _error;
  _PreviewMode _previewMode = _PreviewMode.card;

  bool get _isEditing => widget.existing != null;
  bool get _wasPublished => widget.existing?.published ?? false;

  bool get _isDirty {
    final e = widget.existing;
    return _title.text != (e?.title ?? '') ||
        _summary.text != (e?.summary ?? '') ||
        _body.text != (e?.body ?? '') ||
        _category != e?.category ||
        _featured != (e?.featured ?? false) ||
        _pickedImage != null ||
        _removeImage;
  }

  @override
  void initState() {
    super.initState();
    // La vista previa se redibuja con cada tecla.
    for (final c in [_title, _summary, _body]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _body.dispose();
    super.dispose();
  }

  ImageProvider? get _previewImage {
    if (_pickedImage != null) return MemoryImage(_pickedImage!);
    if (_removeImage) return null;
    final url = widget.existing?.imageUrl;
    return url == null ? null : NetworkImage(url);
  }

  NewsItem get _draft => NewsItem(
        id: widget.existing?.id ?? 'preview',
        title: _title.text.trim(),
        summary: _summary.text.trim(),
        body: _body.text.trim(),
        category: _category,
        featured: _featured,
        createdAt: widget.existing?.createdAt,
        updatedAt: widget.existing?.updatedAt,
      );

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return;
    setState(() {
      _pickedImage = bytes;
      _removeImage = false;
    });
  }

  Future<void> _save({required bool publish}) async {
    // Un borrador puede quedar incompleto; para publicar, todo obligatorio.
    if (publish && !_formKey.currentState!.validate()) return;
    if (!publish && _title.text.trim().isEmpty) {
      setState(() => _error = 'Poné al menos un título para el borrador.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.save(
        widget.tenantId,
        existing: widget.existing,
        title: _title.text.trim(),
        summary: _summary.text.trim(),
        body: _body.text.trim(),
        category: _category,
        featured: _featured,
        published: publish,
        imageBytes: _pickedImage,
        removeImage: _removeImage,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(publish
            ? (_wasPublished ? 'Cambios publicados.' : 'Noticia publicada.')
            : 'Guardada como borrador.'),
      ));
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _close() async {
    if (_saving) return;
    if (_isDirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Descartar cambios?'),
          content: const Text('Lo que escribiste no se va a guardar.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Seguir editando'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 1000;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: wide ? 1080 : 620,
            maxHeight: size.height - 48,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Header(isEditing: _isEditing, onClose: _close),
              const Divider(height: 1),
              Flexible(
                child: wide
                    ? Row(
                        // stretch: las dos columnas (y el divisor) ocupan
                        // todo el alto disponible y scrollean por separado.
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildForm(context)),
                          VerticalDivider(
                              width: 1, color: scheme.outlineVariant),
                          SizedBox(width: 400, child: _buildPreview(context)),
                        ],
                      )
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildForm(context, scrollable: false),
                            const Divider(height: 1),
                            _buildPreview(context),
                          ],
                        ),
                      ),
              ),
              const Divider(height: 1),
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, {bool scrollable = true}) {
    final scheme = Theme.of(context).colorScheme;
    final form = Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _title,
              maxLength: _titleMax,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                labelText: 'Título',
                hintText: 'Ej.: Corte de agua programado en el centro',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 6),
            const _FieldLabel('Categoría'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in kNewsCategories)
                  ChoiceChip(
                    label: Text(c),
                    selected: _category == c,
                    avatar: _category == c
                        ? null
                        : CircleAvatar(
                            backgroundColor: newsCategoryColor(context, c),
                            radius: 5,
                          ),
                    onSelected: (sel) =>
                        setState(() => _category = sel ? c : null),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _summary,
              maxLength: _summaryMax,
              maxLines: 2,
              minLines: 2,
              decoration: const InputDecoration(
                labelText: 'Bajada (opcional)',
                hintText: 'Resumen de una o dos líneas que se ve en la tarjeta',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _body,
              minLines: 8,
              maxLines: 16,
              decoration: const InputDecoration(
                labelText: 'Texto de la noticia',
                hintText: 'Separá los párrafos con un renglón en blanco.',
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 18),
            const _FieldLabel('Imagen'),
            const SizedBox(height: 8),
            _ImageField(
              image: _previewImage,
              onPick: _pickImage,
              onRemove: _previewImage == null
                  ? null
                  : () => setState(() {
                        _pickedImage = null;
                        _removeImage = widget.existing?.imageUrl != null;
                      }),
            ),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: SwitchListTile(
                value: _featured,
                onChanged: (v) => setState(() => _featured = v),
                secondary: Icon(Icons.star_rounded,
                    color: _featured ? Colors.amber : scheme.onSurfaceVariant),
                title: const Text('Destacada'),
                subtitle: const Text(
                    'Se muestra grande, arriba de todas en la app. Si hay '
                    'varias destacadas, va la más reciente.'),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
          ],
        ),
      ),
    );
    return scrollable ? SingleChildScrollView(child: form) : form;
  }

  Widget _buildPreview(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final draft = _draft;
    final image = _previewImage;

    final Widget screen = switch (_previewMode) {
      _PreviewMode.card => ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          children: [
            const NewsSectionHeader(),
            const SizedBox(height: 14),
            if (draft.featured)
              NewsHeroCard(
                item: draft,
                image: image,
                onTap: () =>
                    setState(() => _previewMode = _PreviewMode.detail),
              )
            else
              NewsListCard(
                item: draft,
                image: image,
                onTap: () =>
                    setState(() => _previewMode = _PreviewMode.detail),
              ),
          ],
        ),
      _PreviewMode.detail => NewsDetailPreview(
          item: draft,
          image: image,
          onBack: () => setState(() => _previewMode = _PreviewMode.card),
        ),
    };

    return Container(
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Text('Así se ve en la app',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            SegmentedButton<_PreviewMode>(
              segments: const [
                ButtonSegment(
                  value: _PreviewMode.card,
                  label: Text('Tarjeta'),
                  icon: Icon(Icons.view_agenda_outlined, size: 16),
                ),
                ButtonSegment(
                  value: _PreviewMode.detail,
                  label: Text('Al abrirla'),
                  icon: Icon(Icons.article_outlined, size: 16),
                ),
              ],
              selected: {_previewMode},
              onSelectionChanged: (s) =>
                  setState(() => _previewMode = s.first),
            ),
            const SizedBox(height: 16),
            PhoneFrame(
              seed: widget.brandColor,
              secondary: widget.brandSecondary,
              height: 560,
              child: screen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final publishLabel = _wasPublished ? 'Guardar cambios' : 'Publicar';
    final draftLabel =
        _wasPublished ? 'Despublicar (borrador)' : 'Guardar borrador';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      child: Row(
        children: [
          if (_isEditing && !_wasPublished)
            Text(
              'Borrador — no se ve en la app',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12.5),
            ),
          const Spacer(),
          TextButton(
            onPressed: _saving ? null : _close,
            child: const Text('Cancelar'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _saving ? null : () => _save(publish: false),
            child: Text(draftLabel),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _saving ? null : () => _save(publish: true),
            icon: _saving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(publishLabel),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isEditing, required this.onClose});

  final bool isEditing;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 12, 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isEditing ? Icons.edit_outlined : Icons.campaign_outlined,
              color: scheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Text(isEditing ? 'Editar noticia' : 'Nueva noticia',
              style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ImageField extends StatelessWidget {
  const _ImageField({
    required this.image,
    required this.onPick,
    required this.onRemove,
  });

  final ImageProvider? image;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (image == null) {
      return InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  color: scheme.onSurfaceVariant, size: 28),
              const SizedBox(height: 8),
              Text('Agregar imagen (opcional)',
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 2),
              Text('Horizontal se ve mejor · se optimiza al subir',
                  style: TextStyle(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      fontSize: 11.5)),
            ],
          ),
        ),
      );
    }
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 168,
            height: 96,
            child: NewsImage(image: image!),
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('Cambiar'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRemove,
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Quitar'),
            ),
          ],
        ),
      ],
    );
  }
}
