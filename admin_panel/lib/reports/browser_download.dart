import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Hace que el navegador descargue [bytes] como [fileName]. Aparte de
/// report_export.dart para que la generación de los archivos se pueda
/// probar fuera del navegador (test/report_export_test.dart).
void downloadFile(Uint8List bytes, String fileName, String mimeType) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
