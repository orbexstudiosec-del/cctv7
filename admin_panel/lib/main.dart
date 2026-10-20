import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth/auth_gate.dart';
import 'firebase_options.dart';
import 'shared/theme.dart';
import 'tenant/tenant_branding.dart';
import 'tenant/tenant_config.dart';
import 'tenant/tenant_repository.dart';

/// Desarrollo local: `--dart-define=USE_EMULATOR=true` apunta Auth,
/// Firestore y Storage a los emuladores (`firebase emulators:start` en
/// firebase/, datos de prueba con firebase/scripts/seedEmulator.js).
const _useEmulator = bool.fromEnvironment('USE_EMULATOR');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (_useEmulator) {
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
  }
  runApp(const AdminPanelApp());
}

class AdminPanelApp extends StatefulWidget {
  const AdminPanelApp({super.key});

  @override
  State<AdminPanelApp> createState() => _AdminPanelAppState();
}

class _AdminPanelAppState extends State<AdminPanelApp> {
  final _tenantRepository = TenantRepository();
  late final Future<TenantBranding?> _brandingFuture;

  @override
  void initState() {
    super.initState();
    // Sin timeout, si Firestore no responde (ej. base sin crear) el SDK web
    // reintenta para siempre y el panel queda en el spinner; con error cae
    // en _TenantNotFound.
    _brandingFuture = _tenantRepository
        .fetchBranding(kTenantSlug)
        .timeout(const Duration(seconds: 20));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TenantBranding?>(
      future: _brandingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _ShellApp(
            child: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        final branding = snapshot.data;
        if (branding == null) {
          return const _ShellApp(child: _TenantNotFound());
        }

        return Provider<TenantBranding>.value(
          value: branding,
          child: MaterialApp(
            title: branding.appName,
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(
                seed: branding.primaryColor,
                secondary: branding.secondaryColor),
            home: AuthGate(branding: branding),
          ),
        );
      },
    );
  }
}

/// MaterialApp mínima para los estados de carga/error, antes de tener la
/// marca del tenant (y por lo tanto el theme) resuelta.
class _ShellApp extends StatelessWidget {
  const _ShellApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: child);
  }
}

class _TenantNotFound extends StatelessWidget {
  const _TenantNotFound();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: scheme.errorContainer, shape: BoxShape.circle),
                  child: Icon(Icons.search_off_rounded,
                      size: 30, color: scheme.onErrorContainer),
                ),
                const SizedBox(height: 20),
                Text(
                  'No se pudo cargar el panel',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'No encontramos la configuración del cliente "$kTenantSlug" en Firestore. '
                  'Verifica tu conexión o contacta al soporte.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
