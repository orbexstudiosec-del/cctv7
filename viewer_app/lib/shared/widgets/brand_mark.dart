import 'package:flutter/material.dart';

/// Ícono de marca genérico (círculo con gradiente + play) reutilizado en el
/// intro, el estado vacío de la lista y cualquier lugar donde no haya un
/// logo real del tenant — para que la identidad visual sea consistente.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 72,
    this.iconSize = 32,
    this.icon = Icons.play_arrow_rounded,
    this.gradient,
  });

  final double size;
  final double iconSize;
  final IconData icon;
  final Gradient? gradient;

  static const _defaultGradient = LinearGradient(
    colors: [Color(0xFF6C5CE7), Color(0xFF8E7CFF)],
  );

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = gradient ?? _defaultGradient;
    final glowColor = (effectiveGradient is LinearGradient
        ? effectiveGradient.colors.first
        : Colors.indigo);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: effectiveGradient,
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.4),
            blurRadius: size * 0.42,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: iconSize),
    );
  }
}
