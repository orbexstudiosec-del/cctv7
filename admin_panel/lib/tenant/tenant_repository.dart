import 'package:cloud_firestore/cloud_firestore.dart';

import 'tenant_branding.dart';

/// Trae la marca pública del único tenant que administra este panel
/// (ver [kTenantSlug]) desde `tenantsPublic/{slug}` — lectura sin
/// autenticación, ver firestore.rules.
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
