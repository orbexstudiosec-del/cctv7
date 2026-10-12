import 'package:cloud_firestore/cloud_firestore.dart';

/// Categorías fijas de noticias. Se guardan tal cual (texto) en Firestore;
/// la app de espectadores tiene la misma lista para colores/íconos.
const kNewsCategories = [
  'Local',
  'Nacional',
  'Deportes',
  'Cultura',
  'Comunicados',
  'Programación',
];

/// Una noticia del tenant (doc `tenants/{tenantId}/news/{newsId}`).
/// Las publicadas son de lectura pública (las lee `viewer_app`, sin
/// login); los borradores solo los ve el staff -- ver firestore.rules.
class NewsItem {
  const NewsItem({
    required this.id,
    required this.title,
    required this.body,
    this.summary = '',
    this.category,
    this.imageUrl,
    this.imagePath,
    this.featured = false,
    this.published = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;

  /// Bajada / resumen corto que se muestra en la tarjeta. Si está vacío,
  /// la app usa el comienzo de [body].
  final String summary;
  final String body;
  final String? category;
  final String? imageUrl;

  /// Ruta en Storage de la imagen, para poder borrarla al reemplazarla o
  /// eliminar la noticia.
  final String? imagePath;

  /// Se muestra grande arriba de todo en la app.
  final bool featured;

  /// false = borrador (no se ve en la app).
  final bool published;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory NewsItem.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime? date(Object? v) => v is Timestamp ? v.toDate() : null;
    return NewsItem(
      id: id,
      title: data['title'] as String? ?? '',
      summary: data['summary'] as String? ?? '',
      body: data['body'] as String? ?? '',
      category: data['category'] as String?,
      imageUrl: data['imageUrl'] as String?,
      imagePath: data['imagePath'] as String?,
      featured: data['featured'] == true,
      // Docs viejos sin el campo se consideran publicados.
      published: data['published'] != false,
      createdAt: date(data['createdAt']),
      updatedAt: date(data['updatedAt']),
    );
  }
}
