import 'dart:io';

import 'package:admin_panel/reports/daily_stats.dart';
import 'package:admin_panel/reports/report_export.dart';
import 'package:excel/excel.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final report = StatsReport(
    channelName: 'CCTV CANAL 7',
    from: DateTime(2026, 10, 1),
    to: DateTime(2026, 10, 3),
    brandColor: const Color(0xFF1565C0),
    days: [
      DailyStats(day: DateTime(2026, 10, 1), visitsPhone: 10, visitsTv: 2,
          devicesPhone: 6, devicesTv: 1, installsPhone: 3),
      DailyStats(day: DateTime(2026, 10, 2)),
      DailyStats(day: DateTime(2026, 10, 3), visitsPhone: 4, visitsTv: 5,
          devicesPhone: 2, devicesTv: 2, installsTv: 1),
    ],
  );

  test('Excel: encabezado, un renglón por día y totales', () {
    final bytes = buildExcel(report);
    final sheet = Excel.decodeBytes(bytes)['Reporte'];
    final rows = sheet.rows
        .map((r) => r.map((c) => c?.value?.toString() ?? '').toList())
        .toList();

    final header = rows.indexWhere((r) => r.first == 'Fecha');
    expect(header, greaterThan(0));
    expect(rows[header + 1].take(7), ['01/10/2026', 'jue', '12', '10', '2', '7', '3']);
    expect(rows[header + 2].take(3), ['02/10/2026', 'vie', '0']);
    expect(rows[header + 4].take(7), ['Total', '', '21', '14', '7', '11', '4']);

    final out = Platform.environment['REPORT_OUT'];
    if (out != null) File('$out/reporte.xlsx').writeAsBytesSync(bytes);
  });

  test('PDF: se genera un documento válido', () async {
    final bytes = await buildPdf(report);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');

    final out = Platform.environment['REPORT_OUT'];
    if (out != null) File('$out/reporte.pdf').writeAsBytesSync(bytes);
  });
}
