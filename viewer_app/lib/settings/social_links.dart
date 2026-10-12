import 'package:cloud_firestore/cloud_firestore.dart';

/// Redes sociales del canal, editables desde el panel (sección "Redes
/// sociales"). Viven en `tenants/{tenantId}/settings/social`, de lectura
/// pública -- ver firestore.rules. Cada campo vacío = esa red no se muestra.
/// Mismos campos que admin_panel/lib/settings/social_links_page.dart.
class SocialLinks {
  const SocialLinks({
    this.facebook = '',
    this.instagram = '',
    this.tiktok = '',
    this.youtube = '',
    this.x = '',
    this.whatsapp = '',
    this.website = '',
  });

  final String facebook;
  final String instagram;
  final String tiktok;
  final String youtube;
  final String x;

  /// Número con código de país, solo dígitos (ej. 593991234567).
  final String whatsapp;
  final String website;

  /// (clave, url) de las redes configuradas, en orden de aparición.
  List<(String, String)> get entries => [
        if (facebook.isNotEmpty) ('facebook', facebook),
        if (instagram.isNotEmpty) ('instagram', instagram),
        if (tiktok.isNotEmpty) ('tiktok', tiktok),
        if (youtube.isNotEmpty) ('youtube', youtube),
        if (x.isNotEmpty) ('x', x),
        if (whatsapp.isNotEmpty)
          ('whatsapp', 'https://wa.me/${whatsapp.replaceAll(RegExp(r'\D'), '')}'),
        if (website.isNotEmpty) ('website', website),
      ];

  factory SocialLinks.fromMap(Map<String, dynamic>? data) {
    String s(String key) => (data?[key] as String? ?? '').trim();
    return SocialLinks(
      facebook: s('facebook'),
      instagram: s('instagram'),
      tiktok: s('tiktok'),
      youtube: s('youtube'),
      x: s('x'),
      whatsapp: s('whatsapp'),
      website: s('website'),
    );
  }

  static Stream<SocialLinks> watch(String tenantId) => FirebaseFirestore
      .instance
      .doc('tenants/$tenantId/settings/social')
      .snapshots()
      .map((snap) => SocialLinks.fromMap(snap.data()));
}
