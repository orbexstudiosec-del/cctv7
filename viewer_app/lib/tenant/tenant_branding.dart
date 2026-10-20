import 'package:flutter/material.dart';

/// Marca pública de un tenant (`tenantsPublic/{slug}`), la misma colección
/// que usa el panel admin. Ver docs/ARCHITECTURE.md secciones 2 y 5.
class TenantBranding {
  const TenantBranding({
    required this.tenantId,
    required this.slug,
    required this.appName,
    required this.primaryColor,
    required this.secondaryColor,
    this.logoUrl,
    this.logoOnColorUrl,
    this.faviconUrl,
  });

  final String tenantId;
  final String slug;
  final String appName;
  final Color primaryColor;
  final Color secondaryColor;
  final String? logoUrl;

  /// Variante del logo (blanco/monocromática) pensada para fondos de color
  /// de marca (degradé) — el logo a todo color pierde contraste ahí. Si no
  /// existe, usar [logoUrl] como respaldo.
  final String? logoOnColorUrl;
  final String? faviconUrl;

  factory TenantBranding.fromFirestore(String slug, Map<String, dynamic> data) {
    return TenantBranding(
      tenantId: data['tenantId'] as String,
      slug: slug,
      appName: data['appName'] as String? ?? slug,
      primaryColor: _colorFromHex(data['primaryColor'] as String? ?? '#6AC827'),
      secondaryColor: _colorFromHex(
        data['secondaryColor'] as String? ?? '#E31E24',
      ),
      logoUrl: data['logoUrl'] as String?,
      logoOnColorUrl: data['logoOnColorUrl'] as String?,
      faviconUrl: data['faviconUrl'] as String?,
    );
  }

  /// Para usar sobre el degradé de marca: cae a [logoUrl] si todavía no se
  /// subió una variante blanca.
  String? get logoForBrandBackground => logoOnColorUrl ?? logoUrl;

  static Color _colorFromHex(String hex) {
    final value = hex.replaceAll('#', '');
    return Color(int.parse('FF$value', radix: 16));
  }
}
