import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Theme de la app: claro (blanco, el predeterminado en el celular) u
/// oscuro (negro, el de TV y el del botón de modo oscuro). Solo
/// cambia la `seedColor`/`secondary` según la marca del tenant — todo lo
/// demás (radios, tipografía, elevaciones) es parte del lenguaje visual
/// común de la app.
ThemeData buildViewerTheme({
  required Color seed,
  Color? secondary,
  Brightness brightness = Brightness.dark,
}) {
  final dark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seed,
    secondary: secondary,
    brightness: brightness,
  ).copyWith(surface: dark ? _surface : Colors.white);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: dark ? _background : _lightBackground,
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
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      // Con fondo transparente el AppBar no puede adivinar el color de los
      // íconos de la barra de estado: en modo claro salían blancos.
      systemOverlayStyle:
          dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: _surface,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dividerTheme: DividerThemeData(
      color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.08),
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

/// Colores del logo de Fantástica 98.9 / CCTV Canal 7 (verde de la X y
/// rojo del aro). Se usan mientras carga la marca de Firestore, que trae
/// los mismos valores en `tenantsPublic/canal7`.
const kBrandGreen = Color(0xFF6AC827);
const kBrandRed = Color(0xFFE31E24);

/// Negro de la app en modo oscuro (fondo y tarjetas). El modo claro
/// (blanco) es el de entrada, igual que el splash nativo.
const kAppBackground = Color(0xFF0A0A0E);
const _background = kAppBackground;
const _surface = Color(0xFF17171F);
const _lightBackground = Color(0xFFF2F4F8);

/// Verde (más oscuro que el de la marca) con el que arrancan las
/// cabeceras con degradé: sobre el verde brillante de la marca el círculo
/// verde de la X del logo se perdía.
const kHeaderGreen = Color(0xFF1E5C2E);

/// Gradiente de marca reutilizable (cabeceras con logo): verde oscuro a la
/// izquierda -> rojo secundario del tenant a la derecha. Mezclar dos
/// colores muy distintos (ej. verde y rojo) en línea recta SIEMPRE cruza
/// por un tono sucio — no es cuestión de cuánto ocupe cada uno, es que el
/// camino RGB entre ellos pasa por ahí. Por eso se interpola a través de
/// un pivote oscuro en el medio: verde -> casi negro (solo pierde
/// brillo, no se mezcla con rojo) -> rojo (solo gana brillo).
LinearGradient brandGradient(Color seed, {Color? secondary}) {
  final end =
      secondary ?? Color.alphaBlend(Colors.black.withValues(alpha: 0.4), seed);
  const pivot = kAppBackground;
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [kHeaderGreen, pivot, end],
    stops: const [0.0, 0.5, 1.0],
  );
}
