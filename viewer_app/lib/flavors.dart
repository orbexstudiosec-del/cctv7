import 'dart:ui' show Brightness;

/// Un flavor = un build de la app con su propio build (ícono, nombre,
/// applicationId) pero apuntando al mismo proyecto Firebase, resuelto por
/// `tenantSlug` (mismo slug que `tenantsPublic/{slug}` en Firestore, igual
/// que hace el panel admin con el subdominio). Ver docs/ARCHITECTURE.md.
///
/// `displayName`/`logoAsset` son solo para el splash (`IntroScreen`): la
/// marca "de verdad" (colores, nombre, logo del resto de la app) se lee
/// de Firestore una vez que carga — pero esa carga tarda un toque, y en
/// ese momento todavía no sabemos nada del tenant. Como cada flavor es un
/// único cliente fijo desde que se compila, el splash puede mostrar su
/// marca al instante usando estos valores empaquetados en el APK, sin
/// esperar red.
///
/// Agregar otro build = agregar un valor aquí + su entrypoint
/// `lib/main_<slug>.dart` + su flavor en `android/app/build.gradle.kts` +
/// su logo en `assets/branding/<slug>_logo.png` + (cuando haya Mac) su
/// esquema de Xcode.
enum Flavor { canal7 }

class FlavorConfig {
  const FlavorConfig({
    required this.flavor,
    required this.tenantSlug,
    required this.displayName,
    required this.logoAsset,
    required this.logoOnDarkAsset,
    required this.markAsset,
  });

  final Flavor flavor;
  final String tenantSlug;
  final String displayName;

  /// Logo completo, letras negras: para fondo claro (el de entrada).
  final String logoAsset;

  /// El mismo logo con letras blancas: para fondo oscuro o de color.
  final String logoOnDarkAsset;

  /// Logo según el brillo del fondo donde va.
  String logoFor(Brightness background) =>
      background == Brightness.dark ? logoOnDarkAsset : logoAsset;

  /// Solo el símbolo de la marca (sin texto), para tamaños chicos como la
  /// cabecera, cuando el canal todavía no subió un logo en el panel.
  final String markAsset;

  static FlavorConfig? _instance;

  static FlavorConfig get instance {
    final config = _instance;
    if (config == null) {
      throw StateError(
        'FlavorConfig no inicializado: cada entrypoint (lib/main_<cliente>.dart) '
        'debe llamar a FlavorConfig.initialize() antes de levantar la app.',
      );
    }
    return config;
  }

  static void initialize(FlavorConfig config) => _instance = config;
}
