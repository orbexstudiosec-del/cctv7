import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Reproductor del vivo en iOS, con media_kit (mpv/FFmpeg) en vez de
/// video_player. video_player usa AVPlayer, que no tolera esta señal: el
/// servidor borra los segmentos más viejos antes de sacarlos del playlist
/// (404) y AVPlayer, ante eso, falla y se queda trabado; además informa
/// duración 0 en un vivo, así que no se puede saber cuánto se atrasó. El
/// demuxer HLS de FFmpeg arranca cerca del borde en vivo y saltea un
/// segmento que da 404 en vez de cortar.
///
/// Si igual se termina la reproducción o se congela, se vuelve a abrir solo.
class IosLivePlayer extends StatefulWidget {
  const IosLivePlayer({super.key, required this.url});

  final String url;

  @override
  State<IosLivePlayer> createState() => IosLivePlayerState();
}

class IosLivePlayerState extends State<IosLivePlayer> {
  // ~30 s sin que avance la posición mientras dice estar reproduciendo.
  static const _stallTicksBeforeReopen = 15;
  static const _watchdogInterval = Duration(seconds: 2);

  final _player = Player();
  late final _controller = VideoController(_player);
  final _videoKey = GlobalKey<VideoState>();
  final _subscriptions = <StreamSubscription<Object?>>[];
  Timer? _watchdog;
  Timer? _reopenTimer;
  Duration? _lastPosition;
  int _stallTicks = 0;

  /// Para el botón de pantalla completa propio de la pantalla del canal.
  Future<void> enterFullscreen() async =>
      _videoKey.currentState?.enterFullscreen();

  @override
  void initState() {
    super.initState();
    _subscriptions
      ..add(_player.stream.completed.listen((done) {
        // En un vivo "terminó" significa que se cortó la señal.
        if (done) _scheduleReopen('terminó la reproducción');
      }))
      ..add(_player.stream.error.listen((error) {
        // mpv avisa acá también de fallos que no cortan (un segmento 404):
        // solo se registra; si de verdad se cae, lo detecta completed o el
        // vigilante de congelamiento.
        debugPrint('IosLivePlayer: $error');
      }));
    _watchdog = Timer.periodic(_watchdogInterval, (_) => _checkStall());
    _open();
  }

  @override
  void didUpdateWidget(covariant IosLivePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _open();
  }

  Future<void> _open() async {
    _reopenTimer?.cancel();
    _lastPosition = null;
    _stallTicks = 0;
    await _player.open(Media(widget.url));
  }

  void _checkStall() {
    final state = _player.state;
    if (!state.playing || (_reopenTimer?.isActive ?? false)) {
      _stallTicks = 0;
      return;
    }
    if (_lastPosition == state.position) {
      if (++_stallTicks >= _stallTicksBeforeReopen) {
        _scheduleReopen('video congelado');
      }
    } else {
      _lastPosition = state.position;
      _stallTicks = 0;
    }
  }

  void _scheduleReopen(String reason) {
    if (_reopenTimer?.isActive ?? false) return;
    debugPrint('IosLivePlayer: $reason, reconectando');
    _stallTicks = 0;
    _reopenTimer = Timer(const Duration(seconds: 2), _open);
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _reopenTimer?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  /// Pausar atrasa el vivo; al reanudar se reabre la señal para volver al
  /// borde en vivo en vez de seguir desde donde quedó.
  void _togglePlay() {
    if (_player.state.playing) {
      _player.pause();
    } else {
      _open();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Es un vivo: sin barra de progreso ni gestos para adelantar o retroceder.
    final playButton = _LivePlayButton(
      playing: _player.stream.playing,
      initial: _player.state.playing,
      onPressed: _togglePlay,
    );
    final normal = MaterialVideoControlsThemeData(
      displaySeekBar: false,
      automaticallyImplySkipNextButton: false,
      automaticallyImplySkipPreviousButton: false,
      seekGesture: false,
      seekOnDoubleTap: false,
      primaryButtonBar: [const Spacer(), playButton, const Spacer()],
      bottomButtonBar: const [
        _LiveBadge(),
        Spacer(),
        MaterialFullscreenButton(),
      ],
    );
    final fullscreen = normal.copyWith(
      bottomButtonBarMargin:
          const EdgeInsets.only(left: 16, right: 8, bottom: 42),
    );
    return MaterialVideoControlsTheme(
      normal: normal,
      fullscreen: fullscreen,
      child: Video(key: _videoKey, controller: _controller),
    );
  }
}

class _LivePlayButton extends StatelessWidget {
  const _LivePlayButton({
    required this.playing,
    required this.initial,
    required this.onPressed,
  });

  final Stream<bool> playing;
  final bool initial;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: playing,
      initialData: initial,
      builder: (context, snapshot) => IconButton(
        iconSize: 48,
        color: Colors.white,
        onPressed: onPressed,
        icon: Icon(snapshot.data == true ? Icons.pause : Icons.play_arrow),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'EN VIVO',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
