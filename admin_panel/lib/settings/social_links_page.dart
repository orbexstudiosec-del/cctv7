import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../shared/theme.dart';

/// Redes sociales del canal que aparecen en el menú de la app de celular
/// ("Síguenos"). Se guardan en `tenants/{tenantId}/settings/social`, de
/// lectura pública -- ver firestore.rules. Los mismos campos lee
/// viewer_app/lib/settings/social_links.dart. Campo vacío = esa red no se
/// muestra en la app.
class SocialLinksPage extends StatefulWidget {
  const SocialLinksPage({
    super.key,
    required this.tenantId,
    required this.canManage,
  });

  final String tenantId;
  final bool canManage;

  @override
  State<SocialLinksPage> createState() => _SocialLinksPageState();
}

class _Network {
  const _Network(this.key, this.label, this.icon, this.color, this.hint,
      {this.isPhone = false});

  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final String hint;
  final bool isPhone;
}

const _networks = [
  _Network('facebook', 'Facebook', Icons.facebook, Color(0xFF1877F2),
      'https://www.facebook.com/tu-pagina'),
  _Network('instagram', 'Instagram', Icons.camera_alt_outlined,
      Color(0xFFE1306C), 'https://www.instagram.com/tu-cuenta'),
  _Network('tiktok', 'TikTok', Icons.tiktok, Color(0xFF111111),
      'https://www.tiktok.com/@tu-cuenta'),
  _Network('youtube', 'YouTube', Icons.smart_display_outlined,
      Color(0xFFFF0000), 'https://www.youtube.com/@tu-canal'),
  _Network('x', 'X (Twitter)', Icons.alternate_email_rounded,
      Color(0xFF111111), 'https://x.com/tu-cuenta'),
  _Network('whatsapp', 'WhatsApp', Icons.chat_outlined, Color(0xFF25D366),
      '593991234567', isPhone: true),
  _Network('website', 'Sitio web', Icons.language_rounded, Color(0xFF475569),
      'https://www.tusitio.com'),
];

class _SocialLinksPageState extends State<SocialLinksPage> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = {
    for (final n in _networks) n.key: TextEditingController(),
  };
  bool _loading = true;
  bool _saving = false;
  String? _error;

  DocumentReference<Map<String, dynamic>> get _doc => FirebaseFirestore
      .instance
      .doc('tenants/${widget.tenantId}/settings/social');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snap = await _doc.get();
      final data = snap.data() ?? const {};
      for (final n in _networks) {
        _controllers[n.key]!.text = data[n.key] as String? ?? '';
      }
    } catch (e) {
      _error = 'No se pudo cargar: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  String? _validate(_Network n, String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return null;
    if (n.isPhone) {
      final digits = v.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 10 || digits.length > 15) {
        return 'Número con código de país, ej. 593991234567';
      }
      return null;
    }
    final uri = Uri.tryParse(v);
    if (uri == null || !uri.hasScheme || !uri.scheme.startsWith('http') ||
        uri.host.isEmpty) {
      return 'Pegá el enlace completo, empezando con https://';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _doc.set({
        for (final n in _networks)
          n.key: n.isPhone
              ? _controllers[n.key]!.text.replaceAll(RegExp(r'\D'), '')
              : _controllers[n.key]!.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Redes guardadas. Ya se ven en el menú de la app.'),
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.6)),
              boxShadow: floatingShadow(context),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: scheme.onSurfaceVariant, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Estas redes aparecen en el menú de la app (sección '
                          '"Síguenos"). Dejá vacía la que no uses y no se '
                          'mostrará.',
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  for (final n in _networks) ...[
                    TextFormField(
                      controller: _controllers[n.key],
                      enabled: widget.canManage && !_saving,
                      keyboardType: n.isPhone
                          ? TextInputType.phone
                          : TextInputType.url,
                      decoration: InputDecoration(
                        labelText: n.isPhone
                            ? '${n.label} (número con código de país)'
                            : n.label,
                        hintText: n.hint,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(10),
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: n.color,
                            child: Icon(n.icon, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                      validator: (v) => _validate(n, v),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_error != null) ...[
                    Text(_error!, style: TextStyle(color: scheme.error)),
                    const SizedBox(height: 12),
                  ],
                  if (widget.canManage)
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save_outlined, size: 18),
                        label: const Text('Guardar'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
