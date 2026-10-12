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
    final url = channel.playbackUrl;

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
                child: LivePreviewPlayer(url: url),
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
