import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cuenta visitas para los reportes del panel (Reportes → Excel/PDF). No hay
/// servidor propio ni Analytics: cada apertura suma +1 a contadores en
/// `tenants/{tenantId}/stats/{yyyy-MM-dd}` (un doc por día, fecha local del
/// equipo). firestore.rules solo deja sumar de a 1 a estos campos.
///
/// - `visits`: cada vez que se abre la app, o vuelve después de
///   [_newVisitAfter] en segundo plano.
/// - `devices`: la primera visita del día de cada equipo (únicos por día).
/// - `installs`: la primera vez que se abre la app en ese equipo (si se
///   desinstala y reinstala, vuelve a contar).
///
/// Cada uno se separa además en `<campo>Phone` y `<campo>Tv`.
class UsageTracker with WidgetsBindingObserver {
  UsageTracker._();

  static final instance = UsageTracker._();

  static const _newVisitAfter = Duration(minutes: 30);
  static const _installedKey = 'stats_installed';
  static const _lastDayKey = 'stats_last_day';

  String? _tenantId;
  bool _isTv = false;
  DateTime? _backgroundSince;

  /// Se llama cuando ya se conoce el tenant (al cargar la marca). Las
  /// siguientes llamadas (ej. botón reintentar) no vuelven a contar.
  void start(String tenantId, {required bool isTv}) {
    if (_tenantId != null) return;
    _tenantId = tenantId;
    _isTv = isTv;
    WidgetsBinding.instance.addObserver(this);
    _recordVisit();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _backgroundSince ??= DateTime.now();
      case AppLifecycleState.resumed:
        final since = _backgroundSince;
        _backgroundSince = null;
        if (since != null && DateTime.now().difference(since) >= _newVisitAfter) {
          _recordVisit();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _recordVisit() async {
    final tenantId = _tenantId;
    if (tenantId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final day = _dayKey(DateTime.now());
      final firstEver = !(prefs.getBool(_installedKey) ?? false);
      final firstToday = prefs.getString(_lastDayKey) != day;
      final kind = _isTv ? 'Tv' : 'Phone';
      final one = FieldValue.increment(1);

      // Sin await: Firestore guarda la escritura y la reintenta sola si no
      // hay conexión. Las marcas locales se ponen enseguida para no contar
      // dos veces al mismo equipo.
      FirebaseFirestore.instance
          .doc('tenants/$tenantId/stats/$day')
          .set({
            'visits': one,
            'visits$kind': one,
            if (firstToday) ...{'devices': one, 'devices$kind': one},
            if (firstEver) ...{'installs': one, 'installs$kind': one},
          }, SetOptions(merge: true))
          .catchError((Object _) {});

      await prefs.setBool(_installedKey, true);
      await prefs.setString(_lastDayKey, day);
    } catch (_) {
      // Las estadísticas nunca deben romper la app.
    }
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
