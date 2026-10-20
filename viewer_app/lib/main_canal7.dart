import 'bootstrap.dart';
import 'flavors.dart';

void main() => bootstrap(
  const FlavorConfig(
    flavor: Flavor.canal7,
    tenantSlug: 'canal7',
    displayName: 'CCTV CANAL 7',
    logoAsset: 'assets/branding/canal7_logo.png',
    logoOnDarkAsset: 'assets/branding/canal7_logo_dark.png',
    markAsset: 'assets/branding/canal7_mark.png',
  ),
);
