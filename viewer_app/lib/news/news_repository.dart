import 'package:cloud_firestore/cloud_firestore.dart';

import 'news_item.dart';

/// Lectura (pública, sin auth) de las noticias de un tenant. Ver
/// firestore.rules: solo las publicadas son de lectura pública, y la regla
/// exige que la consulta filtre por `published == true` (si no, Firestore
/// la rechaza entera) -- necesita el índice compuesto published+createdAt
/// de firestore.indexes.json.
class NewsRepository {
  NewsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<NewsItem>> watchNews(String tenantId) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('news')
        .where('published', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => NewsItem.fromFirestore(d.id, d.data()))
              .toList(),
        );
  }
}
