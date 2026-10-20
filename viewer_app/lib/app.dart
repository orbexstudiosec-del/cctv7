import 'package:flutter/material.dart';

import 'channel/channel_screen.dart';
import 'flavors.dart';
import 'shared/theme.dart';
import 'shared/theme_mode.dart';
import 'shared/widgets/intro_screen.dart';
import 'stats/usage_tracker.dart';
import 'tenant/tenant_branding.dart';
import 'tenant/tenant_repository.dart';

class ViewerApp extends StatefulWidget {
  const ViewerApp({super.key});

  @override
  State<ViewerApp> createState() => _ViewerAppState();
}

class _ViewerAppState extends State<ViewerApp> {
  late Future<TenantBranding?> _brandingFuture;

  @override
  void initState() {
    super.initState();
    // La entrada animada se queda al menos 3 s al abrir la app: la carga
    // suele tardar menos y apenas se alcanzaba a ver.
    _brandingFuture = Future.wait([
      _fetchBranding(),
      Future<void>.delayed(const Duration(seconds: 3)),
    ]).then((results) => results.first as TenantBranding?);
  }

  Future<TenantBranding?> _fetchBranding() async {
    final branding = await TenantRepository()
        .fetchBranding(FlavorConfig.instance.tenantSlug);
    if (branding != null) {
      UsageTracker.instance.start(branding.tenantId, isTv: false);
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
        final lightTheme = buildViewerTheme(
          seed: kBrandGreen,
          secondary: kBrandRed,
          brightness: Brightness.light,
        );
        final darkTheme = buildViewerTheme(seed: kBrandGreen, secondary: kBrandRed);
        final mode = ThemeModeController.instance.value;

        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: mode,
            home: const IntroScreen(),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: mode,
            home: IntroScreen(
              errorMessage: 'No se pudo cargar este cliente. Revisa tu conexión e intenta de nuevo.',
              onRetry: _retry,
            ),
          );
        }

        final branding = snapshot.data!;
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeModeController.instance,
          builder: (context, mode, _) => MaterialApp(
            title: branding.appName,
            debugShowCheckedModeBanner: false,
            theme: buildViewerTheme(
              seed: branding.primaryColor,
              secondary: branding.secondaryColor,
              brightness: Brightness.light,
            ),
            darkTheme: buildViewerTheme(
              seed: branding.primaryColor,
              secondary: branding.secondaryColor,
            ),
            themeMode: mode,
            home: ChannelScreen(branding: branding),
          ),
        );
      },
    );
  }
}
