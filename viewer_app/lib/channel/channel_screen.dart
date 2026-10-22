import 'dart:async';
import 'dart:math' as math;

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../flavors.dart';
import '../news/widgets/news_section.dart';
import '../schedule/now_on_air_badge.dart';
import '../schedule/schedule_view.dart';
import '../shared/theme.dart';
import '../shared/theme_mode.dart';
import '../shared/widgets/app_drawer.dart';
import '../shared/widgets/brand_mark.dart';
import '../shared/widgets/status_chip.dart';
import '../tenant/tenant_branding.dart';
import 'channel_repository.dart';
import 'live_playback_controller.dart';
import 'channel_summary.dart';

/// Ventana flotante (PiP, ver MainActivity.kt): mide ~240x135 dp, y un
/// celular tiene como mínimo 320 dp de lado corto. En PiP solo se muestra
/// el video; el resto de la pantalla no entra y se desborda.
bool _isPip(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide < 300;

/// Destello que cruza el logo en diagonal cada pocos segundos. srcATop
/// pinta el brillo solo donde el logo es opaco: el fondo no se ilumina.
class _ShiningLogo extends StatefulWidget {
  const _ShiningLogo({required this.child});

  final Widget child;

  @override
  State<_ShiningLogo> createState() => _ShiningLogoState();
}

class _ShiningLogoState extends State<_ShiningLogo>
    with SingleTickerProviderStateMixin {
  // 1,2 s de barrido y el resto quieto.
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final sweep = (_controller.value / 0.3).clamp(0.0, 1.0);
        if (sweep >= 1) return child!;
        // La franja va de fuera por la izquierda a fuera por la derecha.
        final center = -0.3 + Curves.easeInOut.transform(sweep) * 1.6;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.85),
              Colors.white.withValues(alpha: 0),
            ],
            stops: [center - 0.15, center, center + 0.15],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// La radio hermana del canal: el título de la barra alterna entre el
/// nombre del canal y este.
const _radioName = 'RADIO FANTÁSTICA';

/// Título que gira en 3D (como un cubo sobre el eje horizontal) entre
/// [texts]: se queda quieto [hold] y rota al siguiente.
class _RotatingTitle extends StatefulWidget {
  const _RotatingTitle({required this.texts, required this.style});

  final List<String> texts;
  final TextStyle style;

  static const hold = Duration(seconds: 3);
  static const flip = Duration(milliseconds: 700);

  @override
  State<_RotatingTitle> createState() => _RotatingTitleState();
}

class _RotatingTitleState extends State<_RotatingTitle>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: _RotatingTitle.flip,
  );
  late final _turn = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      _RotatingTitle.hold + _RotatingTitle.flip,
      (_) => _next(),
    );
  }

  Future<void> _next() async {
    if (!mounted || widget.texts.length < 2) return;
    await _controller.forward(from: 0);
    if (!mounted) return;
    setState(() => _index = (_index + 1) % widget.texts.length);
    _controller.value = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _face(String text, double angle, double height) {
    // Cara de un cubo: gira alrededor de su centro, que está a media altura
    // por detrás del texto, así sube/baja además de girar.
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.004)
        ..translateByDouble(0.0, 0.0, height / 2, 1.0)
        ..rotateX(angle)
        ..translateByDouble(0.0, 0.0, -height / 2, 1.0),
      child: Opacity(
        opacity: (1 - angle.abs() / (math.pi / 2)).clamp(0.0, 1.0),
        // Hasta dos líneas: en celulares angostos "RADIO FANTÁSTICA" no
        // entra en una y se cortaba con "…".
        child: Text(
          text,
          style: widget.style.copyWith(height: 1.1),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final texts = widget.texts;
    final current = texts[_index % texts.length];
    final next = texts[(_index + 1) % texts.length];
    // Alto fijo de dos líneas: así el giro no salta entre un nombre que
    // ocupa una línea y otro que ocupa dos.
    final height = (widget.style.fontSize ?? 19) * 1.1 * 2 + 4;

    return SizedBox(
      height: height,
      child: AnimatedBuilder(
        animation: _turn,
        builder: (context, _) {
          final t = _turn.value;
          if (t == 0) {
            return Align(
              alignment: Alignment.centerLeft,
              child: _face(current, 0, height),
            );
          }
          // La cara actual se va hacia arriba y la siguiente entra de abajo.
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              _face(current, -t * math.pi / 2, height),
              _face(next, (1 - t) * math.pi / 2, height),
            ],
          );
        },
      ),
    );
  }
}

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
  /// Qué se ve debajo del video. Acá arriba (no en _LiveChannel) para que
  /// el menú lateral pueda cambiarla.
  final _section = ValueNotifier(_Section.news);

  /// Una sola suscripción por pantalla. Si se pidiera en build(), cada
  /// redibujado (girar a pantalla completa, cambiar el tema) abriría un
  /// stream nuevo: el StreamBuilder vuelve a "waiting", desmonta el
  /// reproductor y la pantalla completa queda en negro con un video liberado.
  late final Stream<ChannelSummary?> _channel =
      ChannelRepository().watchChannel(widget.branding.tenantId);

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
    _section.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final branding = widget.branding;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Barra lisa: blanca en modo claro, negra en oscuro. El logo a
    // todo color se lee bien en las dos (tiene borde blanco).
    final barColor = dark ? kAppBackground : Colors.white;
    final logoUrl = dark ? branding.logoForBrandBackground : branding.logoUrl;

    return Scaffold(
      drawer: AppDrawer(
        branding: branding,
        onOpenNews: () => _section.value = _Section.news,
        onOpenSchedule: () => _section.value = _Section.schedule,
      ),
      appBar: _isPip(context)
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(96),
              // La barra es propia (no AppBar), así que el color de los íconos
              // de la barra de estado hay que fijarlo a mano.
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: dark
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
                  decoration: BoxDecoration(
                    color: barColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: dark ? 0.3 : 0.08,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
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
                            icon: Icon(
                              Icons.menu_rounded,
                              color: scheme.onSurface,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _ShiningLogo(
                          child: logoUrl != null
                              ? Image.network(
                                  logoUrl,
                                  height: 52,
                                  fit: BoxFit.contain,
                                )
                              // Sin logo subido en el panel: el gráfico de la
                              // marca empaquetado en el APK (sin texto,
                              // legible en chico).
                              : Image.asset(
                                  FlavorConfig.instance.markAsset,
                                  height: 58,
                                  fit: BoxFit.contain,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _RotatingTitle(
                            texts: [branding.appName, _radioName],
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        ValueListenableBuilder<ThemeMode>(
                          valueListenable: ThemeModeController.instance,
                          builder: (context, mode, _) => IconButton(
                            tooltip: mode == ThemeMode.dark
                                ? 'Modo claro'
                                : 'Modo oscuro',
                            onPressed: ThemeModeController.instance.toggle,
                            icon: Icon(
                              mode == ThemeMode.dark
                                  ? Icons.light_mode_rounded
                                  : Icons.dark_mode_rounded,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
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
            stream: _channel,
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
              if (channel == null || !channel.hasPlayback || !channel.isLive) {
                return _OffAir(
                  branding: branding,
                  channel: channel,
                  section: _section,
                );
              }

              return _LiveChannel(
                channel: channel,
                branding: branding,
                section: _section,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LiveChannel extends StatefulWidget {
  const _LiveChannel({
    required this.channel,
    required this.branding,
    required this.section,
  });

  final ChannelSummary channel;
  final TenantBranding branding;
  final ValueNotifier<_Section> section;

  @override
  State<_LiveChannel> createState() => _LiveChannelState();
}

class _LiveChannelState extends State<_LiveChannel> {
  LivePlaybackController? _playback;
  ChewieController? _chewieController;
  VideoPlayerController? _chewieFor;

  /// Servidor elegido a mano por el espectador; null = el que toca hoy.
  String? _pickedSourceId;

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

  /// El punto de transmisión que se está reproduciendo.
  StreamSource? get _source {
    final picked = widget.channel.options
        .where((s) => s.id == _pickedSourceId)
        .firstOrNull;
    return picked ?? widget.channel.sourceFor(DateTime.now());
  }

  void _pickSource(String id) {
    if (id == _source?.id) return;
    setState(() => _pickedSourceId = id);
    _syncPlayer();
  }

  void _syncPlayer() {
    final url = _source?.url;
    if (url == null || url.isEmpty) return;
    if (_playback == null) {
      _playback = LivePlaybackController(
        url: url,
        // En iOS el modo textura copia cada cuadro de AVPlayer a una textura
        // de Flutter al ritmo de la pantalla; con la señal de ~6 Mbps se
        // saltea cuadros y el video se ve entrecortado. platformView muestra
        // un AVPlayerLayer nativo, que reproduce fluido.
        viewType: defaultTargetPlatform == TargetPlatform.iOS
            ? VideoViewType.platformView
            : VideoViewType.textureView,
      )
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
              // El botón de pantalla completa es el propio (_FullscreenButton);
              // con el de Chewie salían dos. Para salir: atrás del sistema.
              allowFullScreen: false,
              // Pantalla completa con un botón de salida siempre visible:
              // sin el ícono de Chewie no había cómo volver salvo con atrás.
              routePageBuilder: (context, animation, _, provider) => Scaffold(
                backgroundColor: Colors.black,
                resizeToAvoidBottomInset: false,
                body: Stack(
                  children: [
                    Center(child: provider),
                    Positioned(
                      top: 16,
                      left: 16,
                      child: SafeArea(
                        child: _FullscreenButton(
                          icon: Icons.fullscreen_exit_rounded,
                          onTap: () => _chewieController?.exitFullScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
    final scheme = Theme.of(context).colorScheme;

    if (_isPip(context)) {
      // Sin los controles de Chewie: en la ventana flotante no se pueden
      // usar y tapan el video.
      final video = _chewieController?.videoPlayerController;
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: video == null
              ? const CircularProgressIndicator()
              : AspectRatio(
                  aspectRatio: video.value.aspectRatio,
                  child: VideoPlayer(video),
                ),
        ),
      );
    }

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
              // El fondo negro baja 18 px más que el video para que se vea
              // detrás de las esquinas redondeadas de la hoja, pero el video
              // queda entero arriba: si la hoja lo tapaba, recortaba la barra
              // de controles de Chewie.
              Container(
                width: double.infinity,
                height: videoHeight + 18,
                color: Colors.black,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: videoHeight,
                  child: Center(child: _buildPlayerArea()),
                ),
              ),
              if (_chewieController != null)
                // A media altura del video (el botón mide 44): arriba a la
                // derecha tapaba el logo que el canal pone en su señal.
                Positioned(
                  top: videoHeight / 2 - 22,
                  right: 12,
                  child: _FullscreenButton(
                    onTap: () => _chewieController!.enterFullScreen(),
                  ),
                ),
              Positioned(
                top: videoHeight,
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
                        Row(
                          children: [
                            const StatusChip.live(),
                            const SizedBox(width: 8),
                            Flexible(
                              child: NowOnAirBadge(
                                tenantId: widget.branding.tenantId,
                                accent: widget.branding.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        // Sin título ni descripción del canal: el nombre ya
                        // está en la barra y el programa al aire en el badge.
                        if (widget.channel.options.length > 1) ...[
                          const SizedBox(height: 14),
                          _SourcePicker(
                            options: widget.channel.options,
                            selectedId: _source?.id,
                            accent: widget.branding.primaryColor,
                            onPick: _pickSource,
                          ),
                        ],
                        const SizedBox(height: 18),
                        _BelowVideo(
                          section: widget.section,
                          branding: widget.branding,
                        ),
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
    final url = _source?.url;
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
          detail: _playback!.lastProblem,
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
  const _FullscreenButton({
    required this.onTap,
    this.icon = Icons.fullscreen_rounded,
  });

  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _PlayerPlaceholder extends StatelessWidget {
  const _PlayerPlaceholder({
    required this.icon,
    required this.message,
    this.detail,
    this.onRetry,
  });

  final IconData icon;
  final String message;

  /// Texto técnico chico bajo el mensaje (motivo de la reconexión).
  final String? detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Con el detalle no entra en la altura del video con el padding de 28.
      padding: detail == null
          ? const EdgeInsets.all(28)
          : const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
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
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(
              detail!,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
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
  const _OffAir({
    required this.branding,
    required this.channel,
    required this.section,
  });

  final TenantBranding branding;
  final ChannelSummary? channel;
  final ValueNotifier<_Section> section;

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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: _BelowVideo(section: section, branding: branding),
          ),
        ],
      ),
    );
  }
}

/// Botones para cambiar de punto de transmisión (servidor) sin dejar de
/// ver: solo aparecen si el canal cargó más de uno en el panel.
class _SourcePicker extends StatelessWidget {
  const _SourcePicker({
    required this.options,
    required this.selectedId,
    required this.accent,
    required this.onPick,
  });

  final List<StreamSource> options;
  final String? selectedId;
  final Color accent;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.cell_tower_rounded, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (i, s) in options.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(s.name),
                    selected: s.id == selectedId,
                    showCheckmark: false,
                    selectedColor: accent,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: s.id == selectedId ? Colors.white : scheme.onSurface,
                    ),
                    onSelected: (_) => onPick(s.id),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _Section { news, schedule }

/// Lo que va debajo del video: noticias o programación, con un selector
/// arriba. Cambia solo esta parte — el video sigue reproduciéndose.
class _BelowVideo extends StatelessWidget {
  const _BelowVideo({required this.section, required this.branding});

  final ValueNotifier<_Section> section;
  final TenantBranding branding;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_Section>(
      valueListenable: section,
      builder: (context, current, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<_Section>(
            segments: const [
              ButtonSegment(
                value: _Section.news,
                icon: Icon(Icons.campaign_outlined),
                label: Text('Noticias'),
              ),
              ButtonSegment(
                value: _Section.schedule,
                icon: Icon(Icons.calendar_month_outlined),
                label: Text('Programación'),
              ),
            ],
            selected: {current},
            showSelectedIcon: false,
            // El seleccionado bien marcado (relleno con el color de la
            // marca): el tono suave por defecto casi no se distinguía.
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: branding.primaryColor,
              selectedForegroundColor: Colors.white,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onSelectionChanged: (s) => section.value = s.first,
          ),
          const SizedBox(height: 18),
          if (current == _Section.news)
            // El contenedor ya tiene su margen lateral.
            NewsSection(tenantId: branding.tenantId, padding: EdgeInsets.zero)
          else
            ScheduleView(
              tenantId: branding.tenantId,
              accent: branding.primaryColor,
            ),
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
