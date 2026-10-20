import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modo claro/oscuro elegido con el botón de la barra del canal. Claro por
/// defecto; la elección se guarda en el teléfono.
class ThemeModeController extends ValueNotifier<ThemeMode> {
  ThemeModeController._() : super(ThemeMode.light);

  static final instance = ThemeModeController._();

  static const _key = 'theme_mode';

  /// Lee la elección guardada. Se llama una vez al arrancar (bootstrap).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_key) == 'dark') value = ThemeMode.dark;
  }

  bool get isDark => value == ThemeMode.dark;

  Future<void> toggle() async {
    value = isDark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, isDark ? 'dark' : 'light');
  }
}
