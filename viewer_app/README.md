# viewer_app

App de espectadores de CCTV CANAL 7 (celular y Android TV en un solo APK).
La documentación general está en [../README.md](../README.md).

```
flutter run --flavor canal7 -t lib/main_canal7.dart

# Probar la pantalla de TV en un celular/emulador común
flutter run --flavor canal7 -t lib/main_canal7.dart --dart-define=FORCE_TV=true
```
