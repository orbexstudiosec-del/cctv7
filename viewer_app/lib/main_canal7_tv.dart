import 'bootstrap.dart';
import 'flavors.dart';
import 'tv/tv_app.dart';

/// Entrypoint de la app para Android TV/Google TV — mismo tenant que
/// `main_canal7.dart`, pero una raíz de UI distinta (ver lib/tv/):
/// solo el reproductor a pantalla completa, horizontal, sin el resto de
/// la UI de la app de celular.
void main() => bootstrap(
  const FlavorConfig(
    flavor: Flavor.canal7,
    tenantSlug: 'canal7',
    displayName: 'CCTV CANAL 7',
    logoAsset: 'assets/branding/canal7_logo.png',
  ),
  appBuilder: () => const TvApp(),
);
