import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../flavors.dart';

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
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF15151F), Color(0xFF0A0A0E)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Mark(controller: _controller, isError: isError),
              const SizedBox(height: 28),
              Text(
                FlavorConfig.instance.displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
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
                      color: Colors.white.withValues(alpha: 0.55),
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
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
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
        FlavorConfig.instance.logoAsset,
        width: 150,
        fit: BoxFit.contain,
      ),
    );
  }
}
