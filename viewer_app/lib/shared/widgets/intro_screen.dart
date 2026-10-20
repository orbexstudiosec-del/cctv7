import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../flavors.dart';
import '../theme.dart';

/// Pantalla de arranque mostrada mientras se resuelve el branding del
/// tenant (o si esa carga falla). El logo/nombre vienen de [FlavorConfig]
/// (empaquetados en el APK, ver flavors.dart) — no de Firestore, porque
/// en este momento esa carga todavía no terminó.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, this.errorMessage, this.onRetry});

  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isError = widget.errorMessage != null;
    // Sigue el modo elegido (blanco de entrada, negro con el botón), igual
    // que el splash nativo (blanco) que se ve justo antes.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? Colors.white : const Color(0xFF15151F);
    return Scaffold(
      backgroundColor: dark ? kAppBackground : Colors.white,
      body: Stack(
        children: [
          if (!isError) Positioned.fill(child: _FloatingIcons(dark: dark)),
          SizedBox.expand(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Mark(controller: _controller, isError: isError),
                  const SizedBox(height: 28),
                  Text(
                    FlavorConfig.instance.displayName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: fg,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (isError) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Text(
                        widget.errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: fg.withValues(alpha: 0.6),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (widget.onRetry != null) ...[
                      const SizedBox(height: 22),
                      FilledButton.tonal(
                        onPressed: widget.onRetry,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ] else
                    Text(
                      'Cargando tu contenido…',
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fondo de la entrada: notas musicales (la radio) y cámaras de video (el
/// canal) que suben flotando, se mecen y se desvanecen arriba.
class _FloatingIcons extends StatefulWidget {
  const _FloatingIcons({required this.dark});

  final bool dark;

  @override
  State<_FloatingIcons> createState() => _FloatingIconsState();
}

class _FloatingIconsState extends State<_FloatingIcons>
    with SingleTickerProviderStateMixin {
  static const _cycle = Duration(seconds: 8);
  static const _icons = [
    Icons.music_note_rounded,
    Icons.videocam_rounded,
    Icons.queue_music_rounded,
    Icons.music_note_rounded,
    Icons.videocam_outlined,
    Icons.audiotrack_rounded,
  ];

  late final _controller = AnimationController(vsync: this, duration: _cycle)
    ..repeat();

  // Semilla fija: cada ícono conserva su carril, tamaño y desfase.
  late final List<_Particle> _particles = () {
    final random = math.Random(7);
    return [
      for (var i = 0; i < 16; i++)
        _Particle(
          icon: _icons[i % _icons.length],
          x: (i + random.nextDouble()) / 16,
          size: 20 + random.nextDouble() * 22,
          phase: random.nextDouble(),
          speed: 0.6 + random.nextDouble() * 0.6,
          sway: 10 + random.nextDouble() * 18,
          red: i.isOdd,
        ),
    ];
  }();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strength = widget.dark ? 0.35 : 0.28;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Stack(
              children: [
                for (final p in _particles)
                  () {
                    // 0 = abajo fuera de pantalla, 1 = arriba fuera.
                    final t = (_controller.value * p.speed + p.phase) % 1.0;
                    final wave = math.sin(t * 2 * math.pi * 2 + p.phase * 6);
                    // Aparece y se desvanece en los extremos.
                    final fade = math.sin(t * math.pi);
                    return Positioned(
                      left: p.x * w + wave * p.sway - p.size / 2,
                      top: h + p.size - t * (h + p.size * 2),
                      child: Transform.rotate(
                        angle: wave * 0.35,
                        child: Icon(
                          p.icon,
                          size: p.size,
                          color: (p.red ? kBrandRed : kBrandGreen).withValues(
                            alpha: strength * fade,
                          ),
                        ),
                      ),
                    );
                  }(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.icon,
    required this.x,
    required this.size,
    required this.phase,
    required this.speed,
    required this.sway,
    required this.red,
  });

  final IconData icon;
  final double x;
  final double size;
  final double phase;
  final double speed;
  final double sway;
  final bool red;
}

class _Mark extends StatelessWidget {
  const _Mark({required this.controller, required this.isError});

  final AnimationController controller;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    if (isError) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.redAccent.withValues(alpha: 0.12),
        ),
        child: const Icon(
          Icons.wifi_off_rounded,
          color: Colors.redAccent,
          size: 30,
        ),
      );
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final pulse = 0.9 + 0.1 * math.sin(controller.value * 2 * math.pi);
        return Transform.scale(scale: pulse, child: child);
      },
      child: Image.asset(
        FlavorConfig.instance.logoFor(Theme.of(context).brightness),
        width: 150,
        fit: BoxFit.contain,
      ),
    );
  }
}
