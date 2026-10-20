// admin_panel es solo Flutter Web: dart:html es seguro acá.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/theme.dart';
import '../channel_summary.dart';
import 'live_preview_player.dart';

/// Vista previa de lo que entrega el enlace de la señal ahora mismo (esté
/// el canal al aire o no en las apps) + el link para copiar/compartir.
class ChannelPreviewCard extends StatelessWidget {
  const ChannelPreviewCard({super.key, required this.channel});

  final ChannelSummary channel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // El servidor que están usando las apps hoy.
    final url = channel.urlFor(DateTime.now());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: floatingShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_outline_rounded,
                  color: scheme.primary, size: 20),
              const SizedBox(width: 10),
              Text('Vista previa',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 14),
          if (url == null || url.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Todavía no configuraste el enlace de la señal.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                // Panel en https + señal en http: el navegador bloquea el
                // video ("contenido mixto") y quedaba un reproductor negro.
                // Las apps sí lo reproducen (usesCleartextTraffic).
                child: Uri.base.scheme == 'https' && url.startsWith('http://')
                    ? _MixedContentNotice(url: url)
                    : LivePreviewPlayer(url: url),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.link_rounded,
                      size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      url,
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 12.5),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copiar link',
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: url));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copiado')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MixedContentNotice extends StatelessWidget {
  const _MixedContentNotice({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    // El servidor de la señal sirve su propio reproductor en la raíz (ej.
    // http://190.107.232.9:8082/): abierto en otra pestaña, como página
    // http, el navegador sí reproduce.
    final uri = Uri.parse(url);
    final playerPage = uri.replace(path: '/', query: null).toString();
    return Container(
      color: const Color(0xFF0A0A0E),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_open_rounded, color: Colors.white70, size: 36),
          const SizedBox(height: 14),
          const Text(
            'La vista previa no se puede mostrar en el navegador',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'El enlace de la señal es http (sin candado) y el navegador lo '
            'bloquea dentro de una página segura. En la app de celular y TV '
            'sí se ve. Para tener vista previa acá, pedile al proveedor un '
            'enlace https.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7), height: 1.45),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => html.window.open(playerPage, '_blank'),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Ver la señal en otra pestaña'),
          ),
        ],
      ),
    );
  }
}
