// admin_panel es Flutter Web puro (no hay build para otra plataforma), así
// que dart:html/dart:js son seguros acá -- son justamente lo que hace
// falta para embeber un <video> real controlado por hls.js.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:math' as math;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Vista previa embebida de lo que está saliendo por [url] (HLS). Chrome y
/// Firefox no reproducen .m3u8 nativo como Safari, así que esto usa hls.js
/// (cargado en web/index.html) para decodificarlo en el navegador. Cada
/// instancia registra su propio <video> vía platformViewRegistry, que es
/// la forma estándar de embeber HTML real dentro de Flutter Web.
///
/// Es un vivo que puede quedar abierto horas, así que se recupera solo:
/// errores fatales de hls.js, cortes del servidor y video congelado
/// (currentTime que no avanza) terminan en un reintento con backoff en vez
/// de dejar la imagen colgada.
class LivePreviewPlayer extends StatefulWidget {
  const LivePreviewPlayer({super.key, required this.url});

  final String url;

  @override
  State<LivePreviewPlayer> createState() => _LivePreviewPlayerState();
}

class _LivePreviewPlayerState extends State<LivePreviewPlayer> {
  // Cada cuánto revisa el watchdog, y cuántos chequeos seguidos sin avanzar
  // currentTime cuentan como "colgado".
  static const _watchdogInterval = Duration(seconds: 2);
  static const _stallChecksBeforeRecover = 4; // ~8 s
  static const _maxRetryDelay = Duration(seconds: 30);

  late final String _viewId;
  html.VideoElement? _video;
  js.JsObject? _hls;
  Timer? _watchdog;
  Timer? _retryTimer;
  StreamSubscription<html.Event>? _videoErrorSub;
  StreamSubscription<html.Event>? _visibilitySub;
  double _lastTime = -1;
  int _stalledChecks = 0;
  int _retries = 0;
  bool _mediaRecoveryTried = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _viewId =
        'live-preview-${DateTime.now().microsecondsSinceEpoch}-${widget.hashCode}';
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      final video = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..controls = true
        ..setAttribute('playsinline', '')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#000';
      _video = video;
      // Sólo aplica al modo nativo (Safari); con hls.js los errores llegan
      // por el evento hlsError.
      _videoErrorSub = video.onError.listen((_) {
        if (_hls == null) _scheduleRetry();
      });
      _attach(widget.url);
      _startWatchdog();
      return video;
    });

    // Con la pestaña en segundo plano el navegador frena el video; al volver
    // conviene saltar al borde en vivo en vez de seguir desde atrás.
    _visibilitySub = html.document.onVisibilityChange.listen((_) {
      if (html.document.hidden != true) _jumpToLiveEdge();
    });
  }

  void _attach(String url) {
    final video = _video;
    if (video == null || _disposed) return;
    _teardownHls();
    _retryTimer?.cancel();
    _resetStallTracking();
    _mediaRecoveryTried = false;

    final hlsClass = js.context['Hls'];
    if (hlsClass is js.JsFunction &&
        (hlsClass.callMethod('isSupported') as bool? ?? false)) {
      final hls = js.JsObject(hlsClass, [
        js.JsObject.jsify({
          'enableWorker': true,
          'lowLatencyMode': false,
          // Sin esto hls.js guarda todo lo ya reproducido (Infinity por
          // defecto) y en un vivo de horas la pestaña termina trabándose.
          'backBufferLength': 30,
          'maxBufferLength': 20,
          'maxMaxBufferLength': 40,
          'liveSyncDurationCount': 3,
          'liveMaxLatencyDurationCount': 10,
          'manifestLoadingMaxRetry': 4,
          'levelLoadingMaxRetry': 4,
          'fragLoadingMaxRetry': 4,
        }),
      ]);
      hls.callMethod('on', [
        'hlsError',
        (dynamic _, dynamic data) => _onHlsError(data),
      ]);
      hls.callMethod('on', [
        'hlsManifestParsed',
        (dynamic _, dynamic __) {
          _retries = 0;
          _play();
        },
      ]);
      hls.callMethod('loadSource', [url]);
      hls.callMethod('attachMedia', [video]);
      _hls = hls;
      return;
    }
    // Sin hls.js disponible (no cargó) o no soportado -- Safari reproduce
    // HLS nativo sin necesitar esto.
    video.src = url;
    video.load();
    _play();
  }

  void _onHlsError(dynamic data) {
    if (_disposed || data is! js.JsObject) return;
    if (data['fatal'] != true) return;
    final hls = _hls;
    if (hls == null) return;

    switch (data['type']) {
      case 'networkError':
        // hls.js ya agotó sus reintentos internos; el servidor probablemente
        // está caído o reiniciando. Se recrea todo con backoff.
        _scheduleRetry();
      case 'mediaError':
        // El decoder se trabó: primero el recover liviano, si vuelve a
        // fallar se recrea.
        if (!_mediaRecoveryTried) {
          _mediaRecoveryTried = true;
          hls.callMethod('recoverMediaError');
        } else {
          _scheduleRetry();
        }
      default:
        _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (_disposed) return;
    if (_retryTimer?.isActive ?? false) return;
    _teardownHls();
    final seconds = math.min(
      _maxRetryDelay.inSeconds,
      2 * math.pow(2, math.min(_retries, 4)).toInt(),
    );
    _retries++;
    _retryTimer = Timer(Duration(seconds: seconds), () => _attach(widget.url));
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(_watchdogInterval, (_) => _checkStall());
  }

  void _checkStall() {
    final video = _video;
    if (video == null || _disposed) return;
    // Pausado a mano, pestaña oculta o esperando un reintento: no es cuelgue.
    if (video.paused || html.document.hidden == true) {
      _resetStallTracking();
      return;
    }
    if (_retryTimer?.isActive ?? false) return;

    final now = video.currentTime.toDouble();
    if (now != _lastTime) {
      _lastTime = now;
      _stalledChecks = 0;
      return;
    }
    _stalledChecks++;
    if (_stalledChecks == _stallChecksBeforeRecover ~/ 2) {
      // Primer intento barato: saltar al borde en vivo, suele destrabar
      // cuando quedó parado en un hueco del buffer.
      _jumpToLiveEdge();
    } else if (_stalledChecks >= _stallChecksBeforeRecover) {
      _resetStallTracking();
      _scheduleRetry();
    }
  }

  void _jumpToLiveEdge() {
    final video = _video;
    if (video == null || _disposed) return;
    final livePos = _hls?['liveSyncPosition'];
    if (livePos is num && livePos > video.currentTime) {
      video.currentTime = livePos;
    } else if (video.seekable.length > 0) {
      final end = video.seekable.end(video.seekable.length - 1);
      if (end - video.currentTime > 1) video.currentTime = end - 1;
    }
    _play();
  }

  void _play() {
    final video = _video;
    if (video == null || _disposed) return;
    // play() rechaza la promesa si el navegador bloquea el autoplay; no es
    // un error que haya que propagar.
    video.play().catchError((_) {});
  }

  void _resetStallTracking() {
    _lastTime = -1;
    _stalledChecks = 0;
  }

  void _teardownHls() {
    final hls = _hls;
    _hls = null;
    if (hls != null) {
      try {
        hls.callMethod('destroy');
      } catch (_) {}
    }
  }

  @override
  void didUpdateWidget(covariant LivePreviewPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _retries = 0;
      _attach(widget.url);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _watchdog?.cancel();
    _retryTimer?.cancel();
    _videoErrorSub?.cancel();
    _visibilitySub?.cancel();
    _teardownHls();
    // Soltar el decoder del navegador; si no, el <video> sigue descargando
    // aunque el widget ya no esté en pantalla.
    final video = _video;
    if (video != null) {
      video.pause();
      video.removeAttribute('src');
      video.load();
    }
    _video = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewId);
  }
}
