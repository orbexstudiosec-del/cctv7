import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../channel/channel_repository.dart';
import '../channel/live_playback_controller.dart';
import '../channel/channel_summary.dart';
import '../shared/theme.dart';
import '../shared/widgets/brand_mark.dart';
import '../tenant/tenant_branding.dart';

/// Pantalla única de la app de TV: nada más que el reproductor a pantalla
/// completa. Sin header, sin tarjeta de info, sin noticias — eso vive en
/// `channel/channel_screen.dart` para la app de celular. Acá, en vivo ->
/// video a toda la pantalla; fuera del aire -> solo la marca del canal
/// (sin botón de reintentar: con un control remoto no hay "tocar para
/// reintentar" fácil, así que el reproductor reintenta solo).
class TvPlayerScreen extends StatefulWidget {
  const TvPlayerScreen({super.key, required this.branding});

  final TenantBranding branding;

  @override
  State<TvPlayerScreen> createState() => _TvPlayerScreenState();
}

class _TvPlayerScreenState extends State<TvPlayerScreen> {
  /// Una sola suscripción: pedirla en build() reiniciaba el reproductor en
  /// cada redibujado (ver channel_screen.dart).
  late final Stream<ChannelSummary?> _channel =
      ChannelRepository().watchChannel(widget.branding.tenantId);

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Esta app es solo esta pantalla — mientras esté abierta, que la TV no
    // entre en protector de pantalla ni apague el display.
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<ChannelSummary?>(
        stream: _channel,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Mismo criterio que la app de celular (ver channel_screen.dart):
          // enlace externo + estado puesto desde el panel.
          final channel = snapshot.data;
          if (channel == null || !channel.hasPlayback || !channel.isLive) {
            return _OffAir(branding: widget.branding);
          }

          return _TvPlayer(channel: channel, branding: widget.branding);
        },
      ),
    );
  }
}

class _TvPlayer extends StatefulWidget {
  const _TvPlayer({required this.channel, required this.branding});

  final ChannelSummary channel;
  final TenantBranding branding;

  @override
  State<_TvPlayer> createState() => _TvPlayerState();
}

class _TvPlayerState extends State<_TvPlayer> {
  LivePlaybackController? _playback;
  ChewieController? _chewieController;
  VideoPlayerController? _chewieFor;

  @override
  void initState() {
    super.initState();
    _syncPlayer();
  }

  @override
  void didUpdateWidget(covariant _TvPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPlayer();
  }

  void _syncPlayer() {
    // En TV no hay selector (control remoto): el servidor que toca hoy.
    final url = widget.channel.sourceFor(DateTime.now())?.url;
    if (url == null || url.isEmpty) return;
    if (_playback == null) {
      // Sin control táctil cómodo en un control remoto no hay botón de
      // reintentar: LivePlaybackController reconecta solo ante errores y
      // video congelado.
      _playback = LivePlaybackController(
        url: url,
        // Algunas cajas Android TV genéricas renderizan mal el modo por
        // defecto (TextureView): el área del video sin contenido
        // decodificado queda con el buffer sin inicializar, que en esos
        // chips se ve verde sólido en vez de negro. platformView usa un
        // SurfaceView nativo, que no tiene ese problema.
        viewType: VideoViewType.platformView,
      )
        ..addListener(_onPlaybackChanged)
        ..start();
    } else {
      _playback!.setUrl(url);
    }
  }

  void _onPlaybackChanged() {
    if (!mounted) return;
    final video = _playback?.video;
    if (video != _chewieFor) {
      final oldChewie = _chewieController;
      _chewieFor = video;
      _chewieController = video == null
          ? null
          : ChewieController(
              videoPlayerController: video,
              autoPlay: true,
              looping: false,
              isLive: true,
              showControls: false,
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
    if (_chewieController == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(child: Chewie(controller: _chewieController!));
  }
}

/// Estado de espera: solo la marca del canal, centrada. Sin noticias ni
/// texto largo — esta app es solo-reproductor.
class _OffAir extends StatelessWidget {
  const _OffAir({required this.branding});

  final TenantBranding branding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandMark(
            size: 96,
            iconSize: 40,
            icon: Icons.videocam_off_outlined,
            gradient: brandGradient(
              branding.primaryColor,
              secondary: branding.secondaryColor,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Fuera del aire',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
