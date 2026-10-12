import 'package:flutter/material.dart';

/// Theme único para todo el panel: solo cambia la `seedColor`/`secondary`
/// según la marca del tenant, el resto de la identidad visual (tipografía,
/// inputs, tarjetas, diálogos) es la misma en todos lados.
ThemeData buildAppTheme({required Color seed, Color? secondary}) {
  final colorScheme =
      ColorScheme.fromSeed(seedColor: seed, secondary: secondary);

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surfaceContainerLow,
    splashFactory: InkRipple.splashFactory,
    textTheme: const TextTheme(
      headlineMedium:
          TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4),
      headlineSmall:
          TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: TextStyle(fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(height: 1.4),
      labelLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
    ),
    appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    dialogTheme: DialogThemeData(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
    iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
    popupMenuTheme: PopupMenuThemeData(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: TextStyle(color: colorScheme.onInverseSurface, fontSize: 12),
    ),
  );
}

/// Gradiente de marca reutilizable (cabeceras, sidebar) a partir del color
/// primario del tenant. Mezclar dos colores muy distintos (ej. azul y
/// rojo) en línea recta SIEMPRE cruza por magenta/rosado — no es cuestión
/// de cuánto ocupe cada uno, es que el camino RGB entre ellos pasa por
/// ahí. Por eso se interpola a través de un pivote casi negro en el
/// medio: azul -> casi negro (solo pierde brillo, no se mezcla con rojo)
/// -> rojo (solo gana brillo). Resultado: se ve claramente "azul y rojo",
/// nunca rosa.
LinearGradient brandGradient(Color seed, {Color? secondary}) {
  final end =
      secondary ?? Color.alphaBlend(Colors.black.withValues(alpha: 0.35), seed);
  const pivot = Color(0xFF0A0A12);
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [seed, pivot, end],
    stops: const [0.0, 0.5, 1.0],
  );
}

/// Sombra flotante suave, consistente para tarjetas que necesitan más
/// profundidad que el borde plano del `CardTheme` por defecto.
List<BoxShadow> floatingShadow(BuildContext context) => [
      BoxShadow(
        color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.06),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ];
