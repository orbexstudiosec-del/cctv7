import 'package:flutter/material.dart';

import 'channel/channel_screen.dart';
import 'flavors.dart';
import 'shared/theme.dart';
import 'shared/widgets/intro_screen.dart';
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
    _brandingFuture = _fetchBranding();
  }

  Future<TenantBranding?> _fetchBranding() {
    return TenantRepository().fetchBranding(FlavorConfig.instance.tenantSlug);
  }

  void _retry() {
    setState(() => _brandingFuture = _fetchBranding());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TenantBranding?>(
      future: _brandingFuture,
      builder: (context, snapshot) {
        final defaultTheme = buildViewerTheme(seed: Colors.indigo);

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
              errorMessage: 'No se pudo cargar este cliente. Revisa tu conexión e intenta de nuevo.',
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
          home: ChannelScreen(branding: branding),
        );
      },
    );
  }
}
