import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:flutter/painting.dart' show Color;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'daily_stats.dart';

/// Lo que va en el reporte exportado: mismo contenido en Excel y PDF.
class StatsReport {
  const StatsReport({
    required this.channelName,
    required this.from,
    required this.to,
    required this.days,
    required this.brandColor,
  });

  final String channelName;
  final DateTime from;
  final DateTime to;
  final List<DailyStats> days;
  final Color brandColor;

  StatsTotals get totals => StatsTotals(days);

  String get fileBaseName => 'reporte-visitas-${dayKey(from)}-a-${dayKey(to)}';

  String get rangeLabel => '${formatDay(from)} al ${formatDay(to)}';

  static const columns = [
    'Fecha',
    'Día',
    'Visitas',
    'Visitas celular',
    'Visitas TV',
    'Equipos únicos',
    'Instalaciones',
  ];

  List<Object> rowFor(DailyStats d) => [
        formatDay(d.day),
        weekdayName(d.day),
        d.visits,
        d.visitsPhone,
        d.visitsTv,
        d.devices,
        d.installs,
      ];

  List<Object> get totalsRow {
    final t = totals;
    return [
      'Total',
      '',
      t.visits,
      t.visits - t.visitsTv,
      t.visitsTv,
      t.devices,
      t.installs,
    ];
  }
}

/// El reporte como archivo .xlsx (se descarga con browser_download.dart).
Uint8List buildExcel(StatsReport report) {
  final excel = xl.Excel.createExcel();
  const sheetName = 'Reporte';
  excel.rename(excel.getDefaultSheet()!, sheetName);
  final sheet = excel[sheetName];

  final brandHex = _hex(report.brandColor);
  final titleStyle = xl.CellStyle(bold: true, fontSize: 14);
  final headerStyle = xl.CellStyle(
    bold: true,
    fontColorHex: xl.ExcelColor.white,
    backgroundColorHex: xl.ExcelColor.fromHexString(brandHex),
    horizontalAlign: xl.HorizontalAlign.Center,
  );
  final totalStyle = xl.CellStyle(
    bold: true,
    backgroundColorHex: xl.ExcelColor.fromHexString('#EEEEEE'),
  );

  void styleRow(int row, xl.CellStyle style) {
    for (var c = 0; c < StatsReport.columns.length; c++) {
      sheet
          .cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
          .cellStyle = style;
    }
  }

  xl.CellValue cell(Object v) =>
      v is int ? xl.IntCellValue(v) : xl.TextCellValue('$v');

  sheet.appendRow([xl.TextCellValue('${report.channelName} — Visitas de la app')]);
  sheet
      .cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      .cellStyle = titleStyle;
  sheet.appendRow([xl.TextCellValue('Período: ${report.rangeLabel}')]);
  sheet.appendRow([]);

  final headerRow = sheet.maxRows;
  sheet.appendRow([for (final c in StatsReport.columns) xl.TextCellValue(c)]);
  styleRow(headerRow, headerStyle);

  for (final d in report.days) {
    sheet.appendRow([for (final v in report.rowFor(d)) cell(v)]);
  }

  final totalRow = sheet.maxRows;
  sheet.appendRow([for (final v in report.totalsRow) cell(v)]);
  styleRow(totalRow, totalStyle);

  sheet.appendRow([]);
  for (final note in _notes) {
    sheet.appendRow([xl.TextCellValue(note)]);
  }

  sheet.setColumnWidth(0, 14);
  sheet.setColumnWidth(1, 8);
  for (var c = 2; c < StatsReport.columns.length; c++) {
    sheet.setColumnWidth(c, 16);
  }

  final bytes = excel.encode();
  if (bytes == null) throw StateError('No se pudo generar el Excel.');
  return Uint8List.fromList(bytes);
}

/// El reporte como .pdf (A4, con resumen arriba y la tabla día por día; si
/// el rango es largo sigue en más páginas).
Future<Uint8List> buildPdf(StatsReport report) async {
  final brand = PdfColor.fromInt(report.brandColor.toARGB32());
  final t = report.totals;
  // Sin "—": Helvetica (la fuente que trae el paquete) no la tiene.
  final doc = pw.Document(title: 'Reporte de visitas - ${report.channelName}');

  pw.Widget summaryBox(String label, String value) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.symmetric(horizontal: 4),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold, color: brand)),
              pw.SizedBox(height: 2),
              pw.Text(label,
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            ],
          ),
        ),
      );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : pw.Text('${report.channelName} · ${report.rangeLabel}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Página ${context.pageNumber} de ${context.pagesCount} · '
          'Generado el ${formatDay(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ),
      build: (context) => [
        pw.Text(report.channelName,
            style: pw.TextStyle(
                fontSize: 20, fontWeight: pw.FontWeight.bold, color: brand)),
        pw.SizedBox(height: 2),
        pw.Text('Reporte de visitas de la app · ${report.rangeLabel}',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
        pw.SizedBox(height: 16),
        pw.Row(children: [
          summaryBox('Visitas', '${t.visits}'),
          summaryBox('Equipos únicos', '${t.devices}'),
          summaryBox('Instalaciones nuevas', '${t.installs}'),
          summaryBox(
            'Día con más visitas',
            t.peak == null || t.peak!.visits == 0
                ? '-'
                : formatDayShort(t.peak!.day),
          ),
        ]),
        pw.SizedBox(height: 18),
        pw.TableHelper.fromTextArray(
          headers: StatsReport.columns,
          data: [
            for (final d in report.days)
              [for (final v in report.rowFor(d)) '$v'],
            [for (final v in report.totalsRow) '$v'],
          ],
          headerStyle: pw.TextStyle(
              fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: pw.BoxDecoration(color: brand),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignments: {
            for (var c = 2; c < StatsReport.columns.length; c++)
              c: pw.Alignment.centerRight,
          },
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          border: null,
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        ),
        pw.SizedBox(height: 14),
        for (final note in _notes)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text(note,
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ),
      ],
    ),
  );

  return doc.save();
}

const _notes = [
  'Visitas: cada vez que alguien abre la app (o vuelve después de 30 min).',
  'Equipos únicos: celulares/TVs distintos que abrieron la app ese día.',
  'Instalaciones: primera vez que se abre la app en un equipo. Las descargas '
      'oficiales de Google Play están en Play Console.',
];

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
