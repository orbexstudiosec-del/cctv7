import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'flavors.dart';
import 'shared/theme_mode.dart';
import 'tv/tv_app.dart';

/// Desarrollo local: `--dart-define=USE_EMULATOR=true` apunta Firestore al
/// emulador de Firebase (`firebase emulators:start` en firebase/). Desde el
/// emulador de Android la PC es 10.0.2.2; cambiar con EMULATOR_HOST.
const _useEmulator = bool.fromEnvironment('USE_EMULATOR');
const _emulatorHost = String.fromEnvironment(
  'EMULATOR_HOST',
  defaultValue: '10.0.2.2',
);

/// Para probar la UI de TV en un celular/emulador común:
/// `--dart-define=FORCE_TV=true`.
const _forceTv = bool.fromEnvironment('FORCE_TV');

const _deviceChannel = MethodChannel('viewer_app/device');

/// App iOS de Firebase (canal7app). Va en código y no como
/// `GoogleService-Info.plist` para no tener que agregarlo al proyecto de
/// Xcode; como `google-services.json`, no es un secreto.
const _iosFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyCfKeWubl6VCOomldUrrs_EKhxvqTqrBNQ',
  appId: '1:72308547984:ios:2bbdffe9ebd8c33c041315',
  messagingSenderId: '72308547984',
  projectId: 'canal7app',
  storageBucket: 'canal7app.firebasestorage.app',
  iosBundleId: 'com.orbexstudios.cctvcanal7',
);

/// Arranque común a todos los entrypoints (`lib/main_<cliente>.dart`): fija
/// el flavor activo, inicializa Firebase (en Android lee
/// `google-services.json` del flavor; en iOS usa [_iosFirebaseOptions]) y
/// levanta la app.
///
/// La misma app sirve para celular y Android TV: en una TV levanta
/// [TvApp] (solo el reproductor, horizontal) en vez de [ViewerApp].
Future<void> bootstrap(FlavorConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();
  // En iOS el vivo se reproduce con media_kit (ver IosLivePlayer); Android
  // sigue con video_player y no trae las librerías de mpv.
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    MediaKit.ensureInitialized();
  }
  FlavorConfig.initialize(config);
  await Firebase.initializeApp(
    options: defaultTargetPlatform == TargetPlatform.iOS
        ? _iosFirebaseOptions
        : null,
  );
  if (_useEmulator) {
    FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8080);
  }
  await ThemeModeController.instance.load();

  final isTv = _forceTv || await _isTv();
  if (isTv) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
  runApp(isTv ? const TvApp() : const ViewerApp());
}

/// Lo resuelve MainActivity.kt; en otras plataformas (iOS) no hay canal y
/// se toma como celular.
Future<bool> _isTv() async {
  try {
    return await _deviceChannel.invokeMethod<bool>('isTv') ?? false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}
