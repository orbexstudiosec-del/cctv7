import 'package:flutter/material.dart';

import '../flavors.dart';
import '../shared/theme.dart';
import '../shared/widgets/intro_screen.dart';
import '../stats/usage_tracker.dart';
import '../tenant/tenant_branding.dart';
import '../tenant/tenant_repository.dart';
import 'tv_player_screen.dart';

/// Raíz de la app de TV: resuelve el branding igual que [ViewerApp] (el
/// mismo tenant), pero una vez cargado muestra [TvPlayerScreen] en vez
/// de la UI completa de celular.
class TvApp extends StatefulWidget {
  const TvApp({super.key});

  @override
  State<TvApp> createState() => _TvAppState();
}

class _TvAppState extends State<TvApp> {
  late Future<TenantBranding?> _brandingFuture;

  @override
  void initState() {
    super.initState();
    _brandingFuture = _fetchBranding();
  }

  Future<TenantBranding?> _fetchBranding() async {
    final branding = await TenantRepository()
        .fetchBranding(FlavorConfig.instance.tenantSlug);
    if (branding != null) {
      UsageTracker.instance.start(branding.tenantId, isTv: true);
    }
    return branding;
  }

  void _retry() {
    setState(() => _brandingFuture = _fetchBranding());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TenantBranding?>(
      future: _brandingFuture,
      builder: (context, snapshot) {
        final defaultTheme = buildViewerTheme(seed: kBrandGreen, secondary: kBrandRed);

        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: defaultTheme,
            home: const IntroScreen(),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: defaultTheme,
            home: IntroScreen(
              errorMessage:
                  'No se pudo cargar este cliente. Revisá la conexión.',
              onRetry: _retry,
            ),
          );
        }

        final branding = snapshot.data!;
        return MaterialApp(
          title: branding.appName,
          debugShowCheckedModeBanner: false,
          theme: buildViewerTheme(
            seed: branding.primaryColor,
            secondary: branding.secondaryColor,
          ),
          home: TvPlayerScreen(branding: branding),
        );
      },
    );
  }
}
