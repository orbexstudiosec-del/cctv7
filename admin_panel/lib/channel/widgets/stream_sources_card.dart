import 'package:flutter/material.dart';

import '../../schedule/schedule_slot.dart' show kWeekdaysShort;
import '../../shared/theme.dart';
import '../channel_repository.dart';
import '../channel_summary.dart';
import 'channel_source_dialog.dart';

/// Puntos de transmisión del canal: el **principal** (playbackUrl) y
/// servidores adicionales asignados a días (ej. uno de lunes a viernes y
/// otro el fin de semana). La app usa sola el que toca cada día, y el
/// espectador puede cambiar a otro desde debajo del video.
class StreamSourcesCard extends StatelessWidget {
  const StreamSourcesCard({
    super.key,
    required this.channel,
    required this.tenantId,
    required this.repository,
    required this.canManage,
  });

  final ChannelSummary channel;
  final String tenantId;
  final ChannelRepository repository;
  final bool canManage;

  Future<void> _save(BuildContext context, List<StreamSource> sources) async {
    try {
      await repository.setSources(tenantId, sources);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $e')),
        );
      }
    }
  }

  Future<void> _edit(BuildContext context, [StreamSource? existing]) async {
    final result = await showDialog<StreamSource>(
      context: context,
      builder: (_) => _SourceDialog(existing: existing),
    );
    if (result == null || !context.mounted) return;
    final list = [...channel.sources];
    final i = list.indexWhere((s) => s.id == result.id);
    i >= 0 ? list[i] = result : list.add(result);
    await _save(context, list);
  }

  Future<void> _delete(BuildContext context, StreamSource source) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar servidor'),
        content: Text('¿Eliminar "${source.name}"? Sus días pasan a usar el '
            'servidor principal.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _save(
          context, channel.sources.where((s) => s.id != source.id).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final todayUrl = channel.urlFor(DateTime.now());
    // Días que no tiene asignados ningún servidor adicional: van al principal.
    final principalDays = [
      for (var d = 1; d <= 7; d++)
        if (!channel.sources.any((s) => s.url.isNotEmpty && s.days.contains(d)))
          d,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: floatingShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.cell_tower_rounded, color: scheme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Servidores de transmisión',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              if (canManage)
                TextButton.icon(
                  onPressed: () => _edit(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Agregar servidor'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Cada día la app usa el servidor asignado a ese día; los días sin '
            'servidor usan el principal. Los espectadores también pueden '
            'cambiar de servidor desde la app.',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 16),
          _SourceRow(
            name: 'Principal',
            url: channel.playbackUrl ?? '',
            days: principalDays,
            daysLabelEmpty: 'Sin días (todos tienen otro servidor)',
            isToday: channel.hasPlaybackUrl && todayUrl == channel.playbackUrl,
            onEdit: canManage
                ? () => showDialog<void>(
                      context: context,
                      builder: (_) => ChannelSourceDialog(
                        tenantId: tenantId,
                        repository: repository,
                        existing: channel,
                      ),
                    )
                : null,
          ),
          for (final s in channel.sources) ...[
            const Divider(height: 24),
            _SourceRow(
              name: s.name,
              url: s.url,
              days: s.days,
              daysLabelEmpty: 'Sin días asignados',
              isToday: todayUrl == s.url &&
                  s.days.contains(DateTime.now().weekday),
              onEdit: canManage ? () => _edit(context, s) : null,
              onDelete: canManage ? () => _delete(context, s) : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.name,
    required this.url,
    required this.days,
    required this.daysLabelEmpty,
    required this.isToday,
    this.onEdit,
    this.onDelete,
  });

  final String name;
  final String url;
  final List<int> days;
  final String daysLabelEmpty;
  final bool isToday;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final daysLabel = days.isEmpty
        ? daysLabelEmpty
        : days.length == 7
            ? 'Todos los días'
            : days.map((d) => kWeekdaysShort[d - 1]).join(', ');

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleSmall),
                  if (isToday) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('EN USO HOY',
                          style: TextStyle(
                              color: scheme.onPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(url.isEmpty ? '(sin enlace)' : url,
                  style: TextStyle(
                      color: scheme.onSurfaceVariant, fontSize: 12.5)),
              const SizedBox(height: 2),
              Text(daysLabel,
                  style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (onEdit != null)
          IconButton(
            tooltip: 'Editar',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
        if (onDelete != null)
          IconButton(
            tooltip: 'Eliminar',
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
          ),
      ],
    );
  }
}

/// Alta / edición de un servidor adicional: nombre, enlace y días.
/// Devuelve el [StreamSource] armado (lo guarda la tarjeta).
class _SourceDialog extends StatefulWidget {
  const _SourceDialog({this.existing});

  final StreamSource? existing;

  @override
  State<_SourceDialog> createState() => _SourceDialogState();
}

class _SourceDialogState extends State<_SourceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _url = TextEditingController(text: widget.existing?.url);
  late final Set<int> _days = {...?widget.existing?.days};
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_days.isEmpty) {
      setState(() => _error = 'Elegí al menos un día.');
      return;
    }
    Navigator.of(context).pop(StreamSource(
      id: widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      url: _url.text.trim(),
      days: _days.toList()..sort(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nuevo servidor' : 'Editar servidor'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                autofocus: widget.existing == null,
                decoration: const InputDecoration(
                  labelText: 'Nombre (lo ven los espectadores)',
                  hintText: 'Ej. Servidor 2',
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Poné un nombre' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _url,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Enlace HLS (.m3u8)',
                  hintText: 'http://…/stream.m3u8',
                ),
                validator: validateStreamUrl,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text('Días en que se usa',
                      style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _days
                      ..clear()
                      ..addAll([1, 2, 3, 4, 5])),
                    child: const Text('Lun a Vie'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _days
                      ..clear()
                      ..addAll([6, 7])),
                    child: const Text('Fin de semana'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text(kWeekdaysShort[d - 1]),
                      selected: _days.contains(d),
                      onSelected: (sel) =>
                          setState(() => sel ? _days.add(d) : _days.remove(d)),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
