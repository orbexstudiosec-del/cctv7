// admin_panel es solo Flutter Web: dart:html es seguro acá, se usa para
// achicar la imagen con un <canvas> antes de subirla.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'news_item.dart';

/// CRUD de noticias de un tenant + imagen en Storage. Ver
/// docs/ARCHITECTURE.md y firebase/firestore.rules / storage.rules para
/// quién puede hacer qué.
class NewsRepository {
  NewsRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  /// Lado más largo de la imagen subida. Las fotos de celular pesan varios
  /// MB; en la app se ven a lo sumo a ancho de pantalla, así que mandarlas
  /// enteras solo gasta datos de los espectadores y Storage.
  static const _maxImageSide = 1600;
  static const _jpegQuality = 0.85;

  CollectionReference<Map<String, dynamic>> _news(String tenantId) =>
      _firestore.collection('tenants').doc(tenantId).collection('news');

  /// Todas (incluye borradores) -- solo para el panel.
  Stream<List<NewsItem>> watchNews(String tenantId) {
    return _news(tenantId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => NewsItem.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Crea o actualiza. [existing] nulo = crear. Imagen: [imageBytes] la
  /// reemplaza, [removeImage] la quita; si no, queda la que estaba.
  Future<void> save(
    String tenantId, {
    NewsItem? existing,
    required String title,
    required String summary,
    required String body,
    required String? category,
    required bool featured,
    required bool published,
    Uint8List? imageBytes,
    bool removeImage = false,
  }) async {
    final data = <String, Object?>{
      'title': title,
      'summary': summary,
      'body': body,
      'category': category,
      'featured': featured,
      'published': published,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    String? oldImagePath;
    if (imageBytes != null) {
      final (url, path) = await _uploadImage(tenantId, imageBytes);
      data['imageUrl'] = url;
      data['imagePath'] = path;
      oldImagePath = existing?.imagePath;
    } else if (removeImage) {
      data['imageUrl'] = FieldValue.delete();
      data['imagePath'] = FieldValue.delete();
      oldImagePath = existing?.imagePath;
    }

    if (existing != null) {
      await _news(tenantId).doc(existing.id).update(data);
    } else {
      data['createdAt'] = FieldValue.serverTimestamp();
      await _news(tenantId).add(data);
    }

    // Recién después de guardar: si falla el guardado, la imagen vieja
    // sigue siendo la referenciada.
    if (oldImagePath != null) await _deleteImage(oldImagePath);
  }

  Future<void> setFeatured(String tenantId, String id, bool featured) =>
      _news(tenantId).doc(id).update({'featured': featured});

  Future<void> setPublished(String tenantId, String id, bool published) =>
      _news(tenantId).doc(id).update({
        'published': published,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> delete(String tenantId, NewsItem item) async {
    await _news(tenantId).doc(item.id).delete();
    if (item.imagePath != null) await _deleteImage(item.imagePath!);
  }

  Future<(String url, String path)> _uploadImage(
    String tenantId,
    Uint8List bytes,
  ) async {
    final compressed = await _compress(bytes);
    final path =
        'tenants/$tenantId/news/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref(path);
    await ref.putData(
      compressed,
      SettableMetadata(
        contentType: 'image/jpeg',
        // Las imágenes nunca cambian (cada subida es un archivo nuevo):
        // que la app y los navegadores las guarden en caché.
        cacheControl: 'public, max-age=31536000, immutable',
      ),
    );
    return (await ref.getDownloadURL(), path);
  }

  Future<void> _deleteImage(String path) async {
    try {
      await _storage.ref(path).delete();
    } catch (_) {
      // Ya no existía o sin permiso: no vale la pena frenar el guardado
      // por una imagen huérfana.
    }
  }

  /// Achica a [_maxImageSide] y recodifica a JPEG con un <canvas>. Si algo
  /// falla (formato raro), sube el original.
  Future<Uint8List> _compress(Uint8List bytes) async {
    final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes]));
    try {
      final img = html.ImageElement(src: url);
      await img.onLoad.first.timeout(const Duration(seconds: 15));
      final w = img.naturalWidth;
      final h = img.naturalHeight;
      if (w == 0 || h == 0) return bytes;
      final scale = (w > h ? _maxImageSide / w : _maxImageSide / h);
      final factor = scale < 1 ? scale : 1.0;
      final canvas = html.CanvasElement(
        width: (w * factor).round(),
        height: (h * factor).round(),
      );
      canvas.context2D
        ..fillStyle = '#ffffff' // PNG con transparencia -> fondo blanco
        ..fillRect(0, 0, canvas.width!, canvas.height!)
        ..drawImageScaled(img, 0, 0, canvas.width!, canvas.height!);
      final blob = await canvas.toBlob('image/jpeg', _jpegQuality);
      final reader = html.FileReader()..readAsArrayBuffer(blob);
      await reader.onLoad.first;
      final result = reader.result;
      final out = result is ByteBuffer
          ? result.asUint8List()
          : result is Uint8List
              ? result
              : bytes;
      // Si por algún motivo el JPEG sale más pesado, queda el original.
      return out.length < bytes.length ? out : bytes;
    } catch (_) {
      return bytes;
    } finally {
      html.Url.revokeObjectUrl(url);
    }
  }
}
