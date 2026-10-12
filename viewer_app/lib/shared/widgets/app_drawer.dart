import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../settings/social_links.dart';
import '../../tenant/tenant_branding.dart';
import '../theme.dart';

/// Páginas legales publicadas en Firebase Hosting junto al panel (fuente
/// en admin_panel/web/). Google Play exige que la política de privacidad
/// sea accesible también desde dentro de la app.
const kPrivacyUrl = 'https://canal7app.web.app/privacidad';
const kTermsUrl = 'https://canal7app.web.app/terminos';
const kDeveloperName = 'Orbex Studios';
const kDeveloperEmail = 'orbexstudios.ec@gmail.com';

Future<void> openLink(BuildContext context, String url,
    {bool inApp = false}) async {
  final ok = await launchUrl(
    Uri.parse(url),
    // Páginas propias (privacidad/términos) en una pestaña dentro de la app;
    // redes sociales en su app nativa si está instalada.
    mode: inApp ? LaunchMode.inAppBrowserView : LaunchMode.externalApplication,
  ).catchError((_) => false);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir el enlace.')),
    );
  }
}

/// Menú lateral (hamburguesa) de la app de celular.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.branding});

  final TenantBranding branding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Drawer(
      backgroundColor: scheme.surface,
      child: Column(
        children: [
          _Header(branding: branding),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _Item(
                  icon: Icons.info_outline_rounded,
                  label: 'Acerca de la app',
                  onTap: () => _showSheet(context, _AboutApp(branding: branding)),
                ),
                _Item(
                  icon: Icons.code_rounded,
                  label: 'Sobre el desarrollador',
                  onTap: () => _showSheet(context, const _AboutDeveloper()),
                ),
                const Divider(indent: 20, endIndent: 20),
                _Item(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Política de privacidad',
                  trailing: Icons.open_in_new_rounded,
                  onTap: () => openLink(context, kPrivacyUrl, inApp: true),
                ),
                _Item(
                  icon: Icons.gavel_rounded,
                  label: 'Términos y condiciones',
                  trailing: Icons.open_in_new_rounded,
                  onTap: () => openLink(context, kTermsUrl, inApp: true),
                ),
                StreamBuilder<SocialLinks>(
                  stream: SocialLinks.watch(branding.tenantId),
                  builder: (context, snapshot) {
                    final entries = snapshot.data?.entries ?? const [];
                    if (entries.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          const SizedBox(height: 4),
                          Text(
                            'SÍGUENOS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final (key, url) in entries)
                                _SocialButton(networkKey: key, url: url),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const _VersionFooter(),
        ],
      ),
    );
  }

  void _showSheet(BuildContext context, Widget child) {
    Navigator.of(context).pop(); // cierra el menú primero
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => SafeArea(child: child),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.branding});

  final TenantBranding branding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.paddingOf(context).top + 28, 24, 24),
      decoration: BoxDecoration(
        gradient: brandGradient(
          branding.primaryColor,
          secondary: branding.secondaryColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (branding.logoForBrandBackground != null)
            Image.network(
              branding.logoForBrandBackground!,
              height: 48,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox(height: 48),
            ),
          const SizedBox(height: 14),
          Text(
            branding.appName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Tu canal, siempre contigo',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(icon, color: scheme.onSurfaceVariant),
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      trailing: trailing == null
          ? null
          : Icon(trailing, size: 16, color: scheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.networkKey, required this.url});

  final String networkKey;
  final String url;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (networkKey) {
      'facebook' => (FontAwesomeIcons.facebookF, const Color(0xFF1877F2), 'Facebook'),
      'instagram' => (FontAwesomeIcons.instagram, const Color(0xFFE1306C), 'Instagram'),
      'tiktok' => (FontAwesomeIcons.tiktok, const Color(0xFF111111), 'TikTok'),
      'youtube' => (FontAwesomeIcons.youtube, const Color(0xFFFF0000), 'YouTube'),
      'x' => (FontAwesomeIcons.xTwitter, const Color(0xFF111111), 'X'),
      'whatsapp' => (FontAwesomeIcons.whatsapp, const Color(0xFF25D366), 'WhatsApp'),
      _ => (FontAwesomeIcons.globe, Theme.of(context).colorScheme.primary, 'Sitio web'),
    };
    return Tooltip(
      message: label,
      child: Material(
        color: color,
        shape: const CircleBorder(
          side: BorderSide(color: Colors.white24),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => openLink(context, url),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(child: FaIcon(icon, color: Colors.white, size: 20)),
          ),
        ),
      ),
    );
  }
}

class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) => Text(
            snapshot.hasData ? 'Versión ${snapshot.data!.version}' : '',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutApp extends StatelessWidget {
  const _AboutApp({required this.branding});

  final TenantBranding branding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          if (branding.logoUrl != null)
            Image.network(branding.logoUrl!, height: 72, fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink()),
          const SizedBox(height: 14),
          Text(branding.appName,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) => Text(
              snapshot.hasData ? 'Versión ${snapshot.data!.version}' : ' ',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'La aplicación oficial de CCTV CANAL 7. Mira la señal del '
            'canal en vivo, desde donde estés, y entérate de sus '
            'noticias.\n\n'
            'No necesitas crear una cuenta: abres la app y el canal empieza '
            'a reproducirse, como prender la tele.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.5, color: scheme.onSurface),
          ),
          const SizedBox(height: 20),
          Text(
            '© ${DateTime.now().year} CCTV CANAL 7',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AboutDeveloper extends StatelessWidget {
  const _AboutDeveloper();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.code_rounded, color: scheme.primary, size: 34),
          ),
          const SizedBox(height: 14),
          Text(kDeveloperName,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Desarrollo de apps y plataformas de streaming · Ecuador',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          Text(
            'Esta app y su panel de administración fueron desarrollados '
            'por $kDeveloperName. Si te interesa '
            'una app o una plataforma de transmisión para tu medio o '
            'negocio, escríbenos.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.5, color: scheme.onSurface),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => openLink(
              context,
              'mailto:$kDeveloperEmail?subject=${Uri.encodeComponent('Contacto desde la app CCTV CANAL 7')}',
            ),
            icon: const Icon(Icons.mail_outline_rounded, size: 18),
            label: const Text(kDeveloperEmail),
          ),
        ],
      ),
    );
  }
}
