import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Reproducción en vivo que no se queda colgada. `VideoPlayerController`
/// solo avisa de errores al inicializar; si después ExoPlayer falla a mitad
/// de camino (corte de red, BehindLiveWindow al volver de segundo plano,
/// un corte en el servidor de la señal) o el video se congela
/// sin error, el controller queda muerto para siempre. Esto lo vigila y
/// reconecta solo, con backoff, sin que el espectador tenga que tocar nada
/// (en la TV ni siquiera podría).
///
/// Las pantallas escuchan este objeto y muestran [video] cuando no es null.
/// Cada reconexión crea un `VideoPlayerController` nuevo, así que quien lo
/// envuelva (Chewie) tiene que recrearse cuando cambie la instancia.
class LivePlaybackController extends ChangeNotifier {
  LivePlaybackController({
    required String url,
    this.viewType = VideoViewType.textureView,
  })  // Un parámetro con nombre no puede ser privado (this._url).
      // ignore: prefer_initializing_formals
      : _url = url;

  static const _initTimeout = Duration(seconds: 20);
  static const _watchdogInterval = Duration(seconds: 2);
  // ~12 s sin que avance la posición mientras dice estar reproduciendo.
  static const _stallTicksBeforeReconnect = 6;
  // Cargando (buffering) ExoPlayer se recupera solo cuando la red alcanza:
  // reconectar a los 12 s tiraba el buffer y la carga empezaba de cero.
  static const _bufferingTicksBeforeReconnect = 20;
  static const _maxRetryDelay = Duration(seconds: 15);
  // En un vivo HLS `position` se cuenta desde el inicio de la ventana del
  // playlist (~166 s en la señal del canal) y `duration` es el largo de esa
  // ventana. El servidor borra los segmentos más viejos antes de sacarlos de
  // la lista: si el video se va quedando atrás, termina pidiendo uno borrado
  // (404) y se corta. Si el atraso pasa de [_maxLiveLag], salta a
  // [_liveOffset] del borde en vivo.
  static const _maxLiveLag = Duration(seconds: 70);
  static const _liveOffset = Duration(seconds: 30);
  int _lagLogTicks = 0;

  final VideoViewType viewType;
  String _url;

  VideoPlayerController? _video;
  Timer? _watchdog;
  Timer? _retryTimer;
  int _generation = 0;
  int _retries = 0;
  Duration? _lastPosition;
  int _stallTicks = 0;
  bool _disposed = false;

  /// Controller listo para mostrar, o null mientras conecta/reconecta.
  VideoPlayerController? get video => _video;

  /// true cuando hubo al menos un fallo y está esperando para reintentar.
  bool get isReconnecting => _retryTimer?.isActive ?? false;

  String get url => _url;

  void start() => _open();

  /// Cambiar de URL (p. ej. el canal pega un enlace nuevo en el panel).
  void setUrl(String url) {
    if (url == _url) return;
    _url = url;
    _retries = 0;
    _open();
  }

  Future<void> _open() async {
    if (_disposed) return;
    _retryTimer?.cancel();
    final generation = ++_generation;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(_url),
      viewType: viewType,
    );
    try {
      await controller.initialize().timeout(_initTimeout);
      if (_disposed || generation != _generation) {
        await controller.dispose();
        return;
      }
      // En iOS un vivo informa duración 0 y la posición queda en 0 hasta
      // que arranca: play() ve position == duration, cree que el video
      // terminó y salta a 0, el segmento más viejo del playlist, que el
      // servidor ya borró (404). AVPlayer falla y se reconecta sin fin.
      // Con la posición real cargada antes, play() no salta.
      if (controller.value.duration == Duration.zero) {
        final position = await controller.position;
        if (position != null) {
          controller.value = controller.value.copyWith(position: position);
        }
      }
      await controller.play();
      controller.addListener(_onVideoEvent);
      _swapVideo(controller);
      _retries = 0;
      _resetStall();
      _watchdog ??= Timer.periodic(_watchdogInterval, (_) => _checkStall());
    } catch (e) {
      debugPrint('LivePlayback: fallo al conectar ($e)');
      await controller.dispose();
      if (_disposed || generation != _generation) return;
      _scheduleRetry();
    }
  }

  void _onVideoEvent() {
    final video = _video;
    if (video == null || !video.value.hasError) return;
    debugPrint('LivePlayback: error en reproducción '
        '(${video.value.errorDescription})');
    _scheduleRetry();
  }

  void _checkStall() {
    final video = _video;
    if (video == null || _disposed || isReconnecting) return;
    final value = video.value;
    _keepNearLiveEdge(video);
    // Pausado a mano desde los controles: no es un cuelgue.
    if (!value.isPlaying && !value.isBuffering) {
      _resetStall();
      return;
    }
    if (_lastPosition == value.position) {
      _stallTicks++;
      final limit = value.isBuffering
          ? _bufferingTicksBeforeReconnect
          : _stallTicksBeforeReconnect;
      if (_stallTicks >= limit) {
        debugPrint('LivePlayback: video congelado, reconectando');
        _scheduleRetry(immediate: true);
      }
    } else {
      _lastPosition = value.position;
      _stallTicks = 0;
    }
  }

  void _keepNearLiveEdge(VideoPlayerController video) {
    final window = video.value.duration;
    // Sin ventana conocida (no es un vivo HLS o todavía no la informó).
    if (window <= _maxLiveLag + _liveOffset) return;
    final lag = window - video.value.position;
    if (++_lagLogTicks % 15 == 0) {
      debugPrint('LivePlayback: atraso ${lag.inSeconds}s '
          '(ventana ${window.inSeconds}s)');
    }
    if (lag > _maxLiveLag) {
      debugPrint('LivePlayback: atrasado ${lag.inSeconds}s, vuelvo al vivo');
      video.seekTo(window - _liveOffset);
      _resetStall();
    }
  }

  void _scheduleRetry({bool immediate = false}) {
    if (_disposed || isReconnecting) return;
    _resetStall();
    // Se suelta el controller roto ya mismo: así no queda una imagen
    // congelada en pantalla y se libera el decodificador.
    _swapVideo(null);
    final seconds = immediate
        ? 1
        : math.min(_maxRetryDelay.inSeconds, 2 << math.min(_retries, 3));
    _retries++;
    _retryTimer = Timer(Duration(seconds: seconds), _open);
    notifyListeners();
  }

  void _swapVideo(VideoPlayerController? next) {
    final old = _video;
    _video = next;
    notifyListeners();
    if (old != null) {
      old.removeListener(_onVideoEvent);
      // Después de que la pantalla se reconstruya con el controller nuevo:
      // si se libera en el mismo frame, el widget viejo todavía lo usa.
      Future<void>.delayed(const Duration(milliseconds: 500), old.dispose);
    }
  }

  void _resetStall() {
    _lastPosition = null;
    _stallTicks = 0;
  }

  /// Reintento manual (botón "Reintentar" del celular).
  void retryNow() {
    _retries = 0;
    _retryTimer?.cancel();
    _open();
  }

  @override
  void dispose() {
    _disposed = true;
    _watchdog?.cancel();
    _retryTimer?.cancel();
    _video?.removeListener(_onVideoEvent);
    _video?.dispose();
    _video = null;
    super.dispose();
  }
}
