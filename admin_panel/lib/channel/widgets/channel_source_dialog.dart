import 'package:flutter/material.dart';

import '../channel_repository.dart';
import '../channel_summary.dart';

/// Ver/editar el enlace de la señal del canal. Acá no hay servidor de
/// streaming propio: el proveedor del canal entrega un enlace HLS (.m3u8)
/// ya listo, y lo único que hace el panel es guardarlo para que lo
/// reproduzcan las apps.
class ChannelSourceDialog extends StatefulWidget {
  const ChannelSourceDialog({
    super.key,
    required this.tenantId,
    required this.repository,
    required this.existing,
  });

  final String tenantId;
  final ChannelRepository repository;
  final ChannelSummary existing;

  @override
  State<ChannelSourceDialog> createState() => _ChannelSourceDialogState();
}

class _ChannelSourceDialogState extends State<ChannelSourceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _urlController = TextEditingController(
    text: widget.existing.playbackUrl ?? '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final text = value?.trim() ?? '';
    // Vacío es válido: quita el enlace y las apps quedan "fuera del aire".
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasAuthority) return 'No parece un enlace válido.';
    // Android bloquea el tráfico sin cifrar por defecto y el panel (HTTPS)
    // tampoco puede cargar video http://, así que un enlace http no se
    // vería en ningún lado.
    if (uri.scheme != 'https') return 'El enlace tiene que empezar con https://';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final text = _urlController.text.trim();
      await widget.repository.setPlaybackUrl(
        widget.tenantId,
        text.isEmpty ? null : text,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.link_rounded, color: scheme.primary, size: 18),
          ),
          const SizedBox(width: 12),
          const Text('Enlace de la señal'),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Enlace HLS (.m3u8)',
                  hintText: 'https://…/index.m3u8',
                ),
                validator: _validate,
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pegá el enlace que te entrega tu proveedor de '
                        'streaming. Es lo que reproducen la app de celular y '
                        'la de TV mientras el canal esté al aire; al guardar, '
                        'cambia para todos al instante.',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
