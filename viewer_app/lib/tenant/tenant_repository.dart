import 'package:cloud_firestore/cloud_firestore.dart';

import 'tenant_branding.dart';

/// Trae la marca pública de un tenant por su slug (sin auth, lectura
/// pública — ver firestore.rules). El slug viene embebido en el flavor de
/// este build, no de un subdominio como en el panel web.
class TenantRepository {
  TenantRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<TenantBranding?> fetchBranding(String slug) async {
    final snap = await _firestore.collection('tenantsPublic').doc(slug).get();
    if (!snap.exists) return null;
    return TenantBranding.fromFirestore(slug, snap.data()!);
  }
}
