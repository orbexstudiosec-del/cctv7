// Entrypoint por defecto: alias al flavor de desarrollo (canal7), para que
// `flutter run` sin flags funcione sin tener que recordar `-t`. Los builds
// reales de cada cliente usan su propio `lib/main_<cliente>.dart` con
// `--flavor <cliente>`.
export 'main_canal7.dart';
