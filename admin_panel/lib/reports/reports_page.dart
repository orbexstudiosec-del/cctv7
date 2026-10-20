import 'package:flutter/material.dart';

import '../shared/theme.dart';
import 'browser_download.dart';
import 'daily_stats.dart';
import 'report_export.dart';
import 'stats_repository.dart';

enum _Preset { last7, last30, last90, thisMonth, lastMonth, custom }

const _presetLabels = {
  _Preset.last7: 'Últimos 7 días',
  _Preset.last30: 'Últimos 30 días',
  _Preset.last90: 'Últimos 90 días',
  _Preset.thisMonth: 'Este mes',
  _Preset.lastMonth: 'Mes pasado',
  _Preset.custom: 'Elegir fechas…',
};

/// Reportes de uso de la app (visitas, equipos únicos, instalaciones) por
/// día, con exportación a Excel y PDF. Los datos los escribe la propia app
/// (viewer_app/lib/stats/usage_tracker.dart): empiezan a contar desde la
/// versión que trae ese código.
class ReportsPage extends StatefulWidget {
  const ReportsPage({
    super.key,
    required this.tenantId,
    required this.channelName,
    required this.brandColor,
  });

  final String tenantId;
  final String channelName;
  final Color brandColor;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _repository = StatsRepository();
  _Preset _preset = _Preset.last30;
  late DateTimeRange _range = _rangeFor(_Preset.last30);
  late Future<List<DailyStats>> _future = _load();
  bool _exporting = false;

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTimeRange _rangeFor(_Preset preset) {
    final today = _today;
    DateTime daysAgo(int n) => DateTime(today.year, today.month, today.day - n);
    return switch (preset) {
      _Preset.last7 => DateTimeRange(start: daysAgo(6), end: today),
      _Preset.last30 || _Preset.custom =>
        DateTimeRange(start: daysAgo(29), end: today),
      _Preset.last90 => DateTimeRange(start: daysAgo(89), end: today),
      _Preset.thisMonth =>
        DateTimeRange(start: DateTime(today.year, today.month), end: today),
      _Preset.lastMonth => DateTimeRange(
          start: DateTime(today.year, today.month - 1),
          end: DateTime(today.year, today.month, 0),
        ),
    };
  }

  Future<List<DailyStats>> _load() =>
      _repository.fetchRange(widget.tenantId, _range.start, _range.end);

  Future<void> _selectPreset(_Preset preset) async {
    var range = _rangeFor(preset);
    if (preset == _Preset.custom) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2026),
        lastDate: _today,
        initialDateRange: _range,
        helpText: 'Elegí el período del reporte',
        saveText: 'Aplicar',
      );
      if (picked == null) return;
      range = picked;
    }
    setState(() {
      _preset = preset;
      _range = range;
      _future = _load();
    });
  }

  Future<void> _export(List<DailyStats> days, {required bool pdf}) async {
    final report = StatsReport(
      channelName: widget.channelName,
      from: _range.start,
      to: _range.end,
      days: days,
      brandColor: widget.brandColor,
    );
    setState(() => _exporting = true);
    try {
      if (pdf) {
        downloadFile(await buildPdf(report), '${report.fileBaseName}.pdf',
            'application/pdf');
      } else {
        downloadFile(
          buildExcel(report),
          '${report.fileBaseName}.xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo exportar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: FutureBuilder<List<DailyStats>>(
            future: _future,
            builder: (context, snapshot) {
              final days = snapshot.data;
              final loading =
                  snapshot.connectionState != ConnectionState.done;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Toolbar(
                    preset: _preset,
                    range: _range,
                    onPreset: _selectPreset,
                    onExcel: days == null || _exporting
                        ? null
                        : () => _export(days, pdf: false),
                    onPdf: days == null || _exporting
                        ? null
                        : () => _export(days, pdf: true),
                  ),
                  const SizedBox(height: 20),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.hasError)
                    _Message(
                      icon: Icons.error_outline_rounded,
                      text: 'No se pudieron cargar los reportes: '
                          '${snapshot.error}',
                    )
                  else ...[
                    _Summary(totals: StatsTotals(days!)),
                    const SizedBox(height: 20),
                    if (days.every((d) => d.visits == 0 && d.installs == 0))
                      const _Message(
                        icon: Icons.insights_outlined,
                        text: 'Todavía no hay visitas en este período. Se '
                            'cuentan desde que los espectadores usan la '
                            'versión de la app con reportes.',
                      )
                    else ...[
                      _Panel(
                        title: 'Visitas por día',
                        child: _VisitsChart(
                          days: days,
                          color: widget.brandColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _Panel(
                        title: 'Detalle diario',
                        child: _DailyTable(days: days),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const _Footnote(),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.preset,
    required this.range,
    required this.onPreset,
    required this.onExcel,
    required this.onPdf,
  });

  final _Preset preset;
  final DateTimeRange range;
  final ValueChanged<_Preset> onPreset;
  final VoidCallback? onExcel;
  final VoidCallback? onPdf;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 16,
      runSpacing: 14,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _Preset.values)
                  ChoiceChip(
                    label: Text(_presetLabels[p]!),
                    selected: preset == p,
                    onSelected: (_) => onPreset(p),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${formatDay(range.start)} al ${formatDay(range.end)}',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: onExcel,
              icon: const Icon(Icons.table_view_outlined, size: 18),
              label: const Text('Exportar Excel'),
            ),
            FilledButton.icon(
              onPressed: onPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('Exportar PDF'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.totals});

  final StatsTotals totals;

  @override
  Widget build(BuildContext context) {
    final tvShare = totals.visits == 0
        ? '—'
        : '${(totals.visitsTv * 100 / totals.visits).round()}%';
    final peak = totals.peak;
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _StatCard(
          icon: Icons.visibility_outlined,
          value: '${totals.visits}',
          label: 'Visitas',
        ),
        _StatCard(
          icon: Icons.devices_outlined,
          value: '${totals.devices}',
          label: 'Equipos únicos (suma diaria)',
        ),
        _StatCard(
          icon: Icons.download_outlined,
          value: '${totals.installs}',
          label: 'Instalaciones nuevas',
        ),
        _StatCard(
          icon: Icons.tv_rounded,
          value: tvShare,
          label: 'Visitas desde TV',
        ),
        _StatCard(
          icon: Icons.trending_up_rounded,
          value: peak == null || peak.visits == 0
              ? '—'
              : formatDayShort(peak.day),
          label: peak == null || peak.visits == 0
              ? 'Día con más visitas'
              : 'Día con más visitas (${peak.visits})',
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 178,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: floatingShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(height: 14),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: floatingShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Barras simples, una por día (celular + TV apiladas), con el detalle al
/// pasar el mouse.
class _VisitsChart extends StatelessWidget {
  const _VisitsChart({required this.days, required this.color});

  final List<DailyStats> days;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxVisits = days.fold(0, (m, d) => d.visits > m ? d.visits : m);
    final tvColor = Color.alphaBlend(Colors.white.withValues(alpha: 0.45), color);
    const chartHeight = 180.0;
    final labelEvery = (days.length / 8).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Legend(color: color, label: 'Celular'),
            const SizedBox(width: 16),
            _Legend(color: tvColor, label: 'TV'),
            const Spacer(),
            Text('Máx. $maxVisits',
                style:
                    TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: chartHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in days)
                Expanded(
                  child: Tooltip(
                    message: '${formatDayShort(d.day)}\n'
                        '${d.visits} visitas (${d.visitsPhone} celular, '
                        '${d.visitsTv} TV)\n'
                        '${d.devices} equipos · ${d.installs} instalaciones',
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: days.length > 45 ? 0.5 : 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _bar(d.visitsTv, maxVisits, chartHeight, tvColor,
                              top: true),
                          _bar(d.visitsPhone, maxVisits, chartHeight, color,
                              top: d.visitsTv == 0),
                          if (d.visits == 0)
                            Container(
                              height: 2,
                              color: scheme.outlineVariant
                                  .withValues(alpha: 0.6),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < days.length; i++)
              Expanded(
                child: i % labelEvery == 0
                    ? Text(
                        '${days[i].day.day}/${days[i].day.month}',
                        textAlign: TextAlign.center,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 11),
                      )
                    : const SizedBox(),
              ),
          ],
        ),
      ],
    );
  }

  Widget _bar(int value, int max, double height, Color color,
      {required bool top}) {
    if (value == 0 || max == 0) return const SizedBox();
    return Container(
      height: height * value / max,
      decoration: BoxDecoration(
        color: color,
        borderRadius: top
            ? const BorderRadius.vertical(top: Radius.circular(4))
            : null,
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12.5)),
      ],
    );
  }
}

class _DailyTable extends StatelessWidget {
  const _DailyTable({required this.days});

  final List<DailyStats> days;

  @override
  Widget build(BuildContext context) {
    // Lo más reciente arriba: es lo que se suele buscar primero.
    final rows = days.reversed.toList();
    DataCell n(int v) => DataCell(Text('$v'));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 40,
        columns: const [
          DataColumn(label: Text('Fecha')),
          DataColumn(label: Text('Visitas'), numeric: true),
          DataColumn(label: Text('Celular'), numeric: true),
          DataColumn(label: Text('TV'), numeric: true),
          DataColumn(label: Text('Equipos únicos'), numeric: true),
          DataColumn(label: Text('Instalaciones'), numeric: true),
        ],
        rows: [
          for (final d in rows)
            DataRow(cells: [
              DataCell(Text(formatDayShort(d.day))),
              n(d.visits),
              n(d.visitsPhone),
              n(d.visitsTv),
              n(d.devices),
              n(d.installs),
            ]),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 12.5,
    );
    return Text(
      'Visitas: cada vez que alguien abre la app (o vuelve después de 30 '
      'min). Equipos únicos: celulares/TVs distintos que la abrieron ese día. '
      'Instalaciones: primera vez que se abre en un equipo. Las descargas '
      'oficiales de Google Play se ven en Play Console → Estadísticas.',
      style: style,
    );
  }
}
