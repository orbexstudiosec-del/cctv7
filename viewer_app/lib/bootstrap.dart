import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'flavors.dart';

/// Arranque común a todos los entrypoints (`lib/main_<cliente>.dart`): fija
/// el flavor activo, inicializa Firebase (lee `google-services.json` /
/// `GoogleService-Info.plist` del flavor automáticamente, no necesita
/// `FirebaseOptions` explícitas en móvil) y levanta la app.
///
/// [appBuilder] permite que otro entrypoint (ej. `main_canal7_tv.dart`)
/// levante una raíz distinta a [ViewerApp] — mismo arranque, otra UI.
Future<void> bootstrap(
  FlavorConfig config, {
  Widget Function()? appBuilder,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.initialize(config);
  await Firebase.initializeApp();
  runApp((appBuilder ?? () => const ViewerApp())());
}
