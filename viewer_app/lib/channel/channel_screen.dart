import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../news/widgets/news_section.dart';
import '../shared/theme.dart';
import '../shared/widgets/app_drawer.dart';
import '../shared/widgets/brand_mark.dart';
import '../shared/widgets/status_chip.dart';
import '../tenant/tenant_branding.dart';
import 'channel_repository.dart';
import 'live_playback_controller.dart';
import 'channel_summary.dart';

/// Pantalla única de la app: el canal del tenant. En vivo -> reproduce.
/// Fuera del aire -> estado de espera. Sin lista, sin navegación — abrir la
/// app es como prender la tele. Sin login, lectura pública (ver
/// docs/ARCHITECTURE.md y firestore.rules).
class ChannelScreen extends StatefulWidget {
  const ChannelScreen({super.key, required this.branding});

  final TenantBranding branding;

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  @override
  void initState() {
    super.initState();
    // Esta es la única pantalla de la app — mientras esté abierta, que no
    // se bloquee el celular por el protector de pantalla del sistema.
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final branding = widget.branding;
    final repository = ChannelRepository();

    return Scaffold(
      drawer: AppDrawer(branding: branding),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(88),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 20, 20, 18),
          decoration: BoxDecoration(
            gradient: brandGradient(
              branding.primaryColor,
              secondary: branding.secondaryColor,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                // Builder: el context de acá arriba está por encima del
                // Scaffold, así que Scaffold.of() no lo encontraría.
                Builder(
                  builder: (context) => IconButton(
                    tooltip: 'Menú',
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    icon: const Icon(Icons.menu_rounded,
                        color: Colors.white, size: 26),
                  ),
                ),
                const SizedBox(width: 4),
                if (branding.logoForBrandBackground != null)
                  Image.network(
                    branding.logoForBrandBackground!,
                    height: 36,
                    fit: BoxFit.contain,
                  )
                else
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    branding.appName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: _AmbientGlow(color: branding.primaryColor),
            ),
          ),
          StreamBuilder<ChannelSummary?>(
            stream: repository.watchChannel(branding.tenantId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _MessageState(
                  icon: Icons.error_outline_rounded,
                  iconColor: Colors.redAccent,
                  title: 'Algo salió mal',
                  message: '${snapshot.error}',
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // La señal viene de un enlace externo (el proveedor de
              // streaming del canal), sin servidor propio que avise si
              // está arriba: el interruptor es el estado que el canal
              // pone desde el panel ("Salir al aire" / "Finalizar").
              final channel = snapshot.data;
              final hasPlayback = channel?.playbackUrl?.isNotEmpty ?? false;
              if (channel == null || !hasPlayback || !channel.isLive) {
                return _OffAir(branding: branding, channel: channel);
              }

              return _LiveChannel(channel: channel, branding: branding);
            },
          ),
        ],
      ),
    );
  }
}

class _LiveChannel extends StatefulWidget {
  const _LiveChannel({required this.channel, required this.branding});

  final ChannelSummary channel;
  final TenantBranding branding;

  @override
  State<_LiveChannel> createState() => _LiveChannelState();
}

class _LiveChannelState extends State<_LiveChannel> {
  LivePlaybackController? _playback;
  ChewieController? _chewieController;
  VideoPlayerController? _chewieFor;

  @override
  void initState() {
    super.initState();
    _syncPlayer();
  }

  @override
  void didUpdateWidget(covariant _LiveChannel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPlayer();
  }

  void _syncPlayer() {
    final url = widget.channel.playbackUrl;
    if (url == null || url.isEmpty) return;
    if (_playback == null) {
      _playback = LivePlaybackController(url: url)
        ..addListener(_onPlaybackChanged)
        ..start();
    } else {
      _playback!.setUrl(url);
    }
  }

  /// Cada reconexión trae un VideoPlayerController nuevo: Chewie se arma
  /// de nuevo alrededor de él (el viejo lo libera LivePlaybackController).
  void _onPlaybackChanged() {
    if (!mounted) return;
    final video = _playback?.video;
    if (video != _chewieFor) {
      final oldChewie = _chewieController;
      // Si estaba en pantalla completa, Chewie empuja su propia ruta con el
      // controller viejo: hay que cerrarla antes de reemplazarlo.
      if (oldChewie?.isFullScreen ?? false) oldChewie!.exitFullScreen();
      _chewieFor = video;
      _chewieController = video == null
          ? null
          : ChewieController(
              videoPlayerController: video,
              autoPlay: true,
              looping: false,
              isLive: true,
              materialProgressColors: ChewieProgressColors(
                playedColor: widget.branding.primaryColor,
                handleColor: widget.branding.primaryColor,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white10,
              ),
            );
      WidgetsBinding.instance.addPostFrameCallback((_) => oldChewie?.dispose());
    }
    setState(() {});
  }

  @override
  void dispose() {
    _playback?.removeListener(_onPlaybackChanged);
    _chewieController?.dispose();
    _playback?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final videoHeight = constraints.maxWidth * 9 / 16;
        // Sin este SizedBox, el Stack se encoge al tamaño de su hijo no
        // posicionado más grande (el video) en vez de ocupar la pantalla
        // completa, y el Positioned(bottom: 0) de abajo queda recortado.
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                height: videoHeight,
                child: Container(
                  color: Colors.black,
                  child: Center(child: _buildPlayerArea()),
                ),
              ),
              if (_chewieController != null)
                Positioned(
                  top: 12,
                  right: 12,
                  child: _FullscreenButton(
                    onTap: () => _chewieController!.enterFullScreen(),
                  ),
                ),
              Positioned(
                top: videoHeight - 18,
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const StatusChip.live(),
                        const SizedBox(height: 14),
                        Text(
                          channel.title.isEmpty
                              ? widget.branding.appName
                              : channel.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          channel.description.isEmpty
                              ? 'Transmisión en vivo de ${widget.branding.appName}.'
                              : channel.description,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Divider(
                          color: scheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            if (widget.branding.logoUrl != null)
                              Image.network(
                                widget.branding.logoUrl!,
                                height: 32,
                                fit: BoxFit.contain,
                              )
                            else
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  color: scheme.primary,
                                  size: 18,
                                ),
                              ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.branding.appName,
                                style: Theme.of(context).textTheme.titleSmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        NewsSection(tenantId: widget.branding.tenantId),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerArea() {
    final url = widget.channel.playbackUrl;
    if (url == null || url.isEmpty) {
      return const _PlayerPlaceholder(
        icon: Icons.videocam_off_outlined,
        message: 'El canal está en vivo pero todavía no hay video configurado.',
      );
    }
    if (_chewieController == null) {
      // Reintenta solo; el botón es por si alguien no quiere esperar.
      if (_playback?.isReconnecting ?? false) {
        return _PlayerPlaceholder(
          icon: Icons.wifi_tethering_rounded,
          message: 'Reconectando con la transmisión…',
          onRetry: _playback!.retryNow,
        );
      }
      return const CircularProgressIndicator();
    }
    return Chewie(controller: _chewieController!);
  }
}

/// Botón de pantalla completa propio, más visible que el ícono chico de
/// los controles de Chewie (que además se ocultan solos a los pocos
/// segundos) — siempre visible arriba a la derecha del video.
class _FullscreenButton extends StatelessWidget {
  const _FullscreenButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.fullscreen_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _PlayerPlaceholder extends StatelessWidget {
  const _PlayerPlaceholder({
    required this.icon,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white70, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Estado de espera cuando el canal no está en vivo.
class _OffAir extends StatelessWidget {
  const _OffAir({required this.branding, required this.channel});

  final TenantBranding branding;
  final ChannelSummary? channel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 56, 32, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BrandMark(
                  size: 88,
                  iconSize: 38,
                  icon: Icons.videocam_off_outlined,
                  gradient: brandGradient(
                    branding.primaryColor,
                    secondary: branding.secondaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Fuera del aire',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  '${branding.appName} no está transmitiendo en este momento. '
                  'Volvé más tarde para verlo en vivo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
                ),
              ],
            ),
          ),
          NewsSection(tenantId: branding.tenantId),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: (iconColor ?? scheme.onSurfaceVariant).withValues(
                  alpha: 0.12,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: iconColor ?? scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Resplandor decorativo detrás del contenido, con el color de marca del
/// tenant, para que el fondo no sea negro plano.
class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -140,
          left: -80,
          right: -80,
          child: Container(
            height: 360,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color.withValues(alpha: 0.22), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
