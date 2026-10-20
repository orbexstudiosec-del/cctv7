/// Contadores de un día, tal como los escribe la app en
/// `tenants/{tenantId}/stats/{yyyy-MM-dd}` (ver
/// viewer_app/lib/stats/usage_tracker.dart). Un día sin doc = todo en 0.
class DailyStats {
  const DailyStats({
    required this.day,
    this.visitsPhone = 0,
    this.visitsTv = 0,
    this.devicesPhone = 0,
    this.devicesTv = 0,
    this.installsPhone = 0,
    this.installsTv = 0,
  });

  factory DailyStats.fromFirestore(DateTime day, Map<String, dynamic> data) {
    int read(String key) => (data[key] as num?)?.toInt() ?? 0;
    return DailyStats(
      day: day,
      visitsPhone: read('visitsPhone'),
      visitsTv: read('visitsTv'),
      devicesPhone: read('devicesPhone'),
      devicesTv: read('devicesTv'),
      installsPhone: read('installsPhone'),
      installsTv: read('installsTv'),
    );
  }

  final DateTime day;
  final int visitsPhone;
  final int visitsTv;
  final int devicesPhone;
  final int devicesTv;
  final int installsPhone;
  final int installsTv;

  int get visits => visitsPhone + visitsTv;
  int get devices => devicesPhone + devicesTv;
  int get installs => installsPhone + installsTv;
}

/// Totales de un rango de días.
class StatsTotals {
  StatsTotals(List<DailyStats> days)
      : visits = _sum(days, (d) => d.visits),
        visitsTv = _sum(days, (d) => d.visitsTv),
        devices = _sum(days, (d) => d.devices),
        installs = _sum(days, (d) => d.installs),
        installsTv = _sum(days, (d) => d.installsTv),
        peak = days.isEmpty
            ? null
            : days.reduce((a, b) => b.visits > a.visits ? b : a);

  final int visits;
  final int visitsTv;

  /// Suma de los únicos de cada día (un equipo que entra 3 días cuenta 3).
  final int devices;
  final int installs;
  final int installsTv;
  final DailyStats? peak;

  static int _sum(List<DailyStats> days, int Function(DailyStats) f) =>
      days.fold(0, (total, d) => total + f(d));
}

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

const _weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _months = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// "19/10/2026"
String formatDay(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';

/// "lun 19 oct"
String formatDayShort(DateTime d) =>
    '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

String weekdayName(DateTime d) => _weekdays[d.weekday - 1];
