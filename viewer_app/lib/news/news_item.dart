import 'package:cloud_firestore/cloud_firestore.dart';

/// Una noticia del tenant (doc `tenants/{tenantId}/news/{newsId}`).
/// Lectura pública solo de las publicadas (sin login) — ver
/// firestore.rules. Mismos campos que `admin_panel/lib/news/news_item.dart`
/// (los widgets de `widgets/news_visuals.dart` se comparten entre ambos).
class NewsItem {
  const NewsItem({
    required this.id,
    required this.title,
    required this.body,
    this.summary = '',
    this.category,
    this.imageUrl,
    this.featured = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String summary;
  final String body;
  final String? category;
  final String? imageUrl;
  final bool featured;
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
      featured: data['featured'] == true,
      createdAt: date(data['createdAt']),
      updatedAt: date(data['updatedAt']),
    );
  }
}
