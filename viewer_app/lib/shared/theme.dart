import 'package:flutter/material.dart';

/// Theme oscuro "cinema" por defecto (como la mayoría de apps de streaming/
/// video): fondo casi negro para resaltar miniaturas y reproductor. Solo
/// cambia la `seedColor`/`secondary` según la marca del tenant — todo lo
/// demás (radios, tipografía, elevaciones) es parte del lenguaje visual
/// común de la app.
ThemeData buildViewerTheme({required Color seed, Color? secondary}) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seed,
    secondary: secondary,
    brightness: Brightness.dark,
  ).copyWith(surface: _surface);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: _background,
    splashFactory: InkRipple.splashFactory,
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
      titleLarge: TextStyle(fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(height: 1.4),
      labelLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: _surface,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.white.withValues(alpha: 0.08),
      space: 32,
    ),
    iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
    ),
  );
}

const _background = Color(0xFF0A0A0E);
const _surface = Color(0xFF17171F);

/// Gradiente de marca reutilizable (cabeceras, splash) a partir del color
/// primario del tenant. Mezclar dos colores muy distintos (ej. azul y
/// rojo) en línea recta SIEMPRE cruza por magenta/rosado — no es cuestión
/// de cuánto ocupe cada uno, es que el camino RGB entre ellos pasa por
/// ahí. Por eso se interpola a través de un pivote casi negro en el
/// medio: azul -> casi negro (solo pierde brillo, no se mezcla con rojo)
/// -> rojo (solo gana brillo). Resultado: se ve claramente "azul y rojo",
/// nunca rosa.
LinearGradient brandGradient(Color seed, {Color? secondary}) {
  final end =
      secondary ?? Color.alphaBlend(Colors.black.withValues(alpha: 0.4), seed);
  const pivot = Color(0xFF0A0A12);
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [seed, pivot, end],
    stops: const [0.0, 0.5, 1.0],
  );
}
