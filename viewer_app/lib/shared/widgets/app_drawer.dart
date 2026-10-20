import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../flavors.dart';
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

Future<void> openLink(
  BuildContext context,
  String url, {
  bool inApp = false,
}) async {
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
  const AppDrawer({
    super.key,
    required this.branding,
    required this.onOpenNews,
    required this.onOpenSchedule,
  });

  final TenantBranding branding;

  /// Muestran la pestaña "Noticias" / "Programación" debajo del video (no
  /// abren otra pantalla, para que la señal se siga viendo).
  final VoidCallback onOpenNews;
  final VoidCallback onOpenSchedule;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = branding.primaryColor;
    final secondary = branding.secondaryColor;

    void closeThen(VoidCallback action) {
      Navigator.of(context).pop(); // cierra el menú
      action();
    }

    return Drawer(
      backgroundColor: scheme.surface,
      child: Column(
        children: [
          _Header(branding: branding),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              children: [
                _Item(
                  icon: Icons.live_tv_rounded,
                  color: secondary,
                  label: 'Ver en vivo',
                  onTap: () => Navigator.of(context).pop(),
                ),
                _Item(
                  icon: Icons.newspaper_rounded,
                  color: primary,
                  label: 'Noticias',
                  onTap: () => closeThen(onOpenNews),
                ),
                _Item(
                  icon: Icons.calendar_month_rounded,
                  color: primary,
                  label: 'Programación',
                  onTap: () => closeThen(onOpenSchedule),
                ),
                const _SectionLabel('INFORMACIÓN'),
                _Item(
                  icon: Icons.info_outline_rounded,
                  label: 'Acerca de la app',
                  onTap: () =>
                      _showSheet(context, _AboutApp(branding: branding)),
                ),
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
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionLabel('SÍGUENOS'),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final (key, url) in entries)
                                  _SocialButton(networkKey: key, url: url),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          _VersionFooter(
            onDeveloperTap: () => _showSheet(context, const _AboutDeveloper()),
          ),
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
        24,
        MediaQuery.paddingOf(context).top + 28,
        24,
        24,
      ),
      decoration: BoxDecoration(
        gradient: brandGradient(
          branding.primaryColor,
          secondary: branding.secondaryColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo sobre una placa blanca: el logo a todo color se lee mejor
          // así que sobre el degradé.
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox(
              height: 64,
              child: branding.logoUrl != null
                  ? Image.network(
                      branding.logoUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          Image.asset(FlavorConfig.instance.logoAsset),
                    )
                  : Image.asset(FlavorConfig.instance.logoAsset),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            branding.appName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const _Pill(icon: Icons.live_tv_rounded, text: 'TV en vivo'),
              const SizedBox(width: 8),
              const _Pill(icon: Icons.radio_rounded, text: 'Radio 98.9'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Fila del menú: ícono en una cápsula de color + texto. Los accesos
/// principales llevan el color de la marca; el resto, gris.
class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: color == null ? 0.1 : 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 21, color: tint),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: color == null
                          ? FontWeight.w500
                          : FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (trailing != null)
                  Icon(trailing, size: 16, color: scheme.onSurfaceVariant)
                else if (color != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
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
      'facebook' => (
        FontAwesomeIcons.facebookF,
        const Color(0xFF1877F2),
        'Facebook',
      ),
      'instagram' => (
        FontAwesomeIcons.instagram,
        const Color(0xFFE1306C),
        'Instagram',
      ),
      'tiktok' => (FontAwesomeIcons.tiktok, const Color(0xFF111111), 'TikTok'),
      'youtube' => (
        FontAwesomeIcons.youtube,
        const Color(0xFFFF0000),
        'YouTube',
      ),
      'x' => (FontAwesomeIcons.xTwitter, const Color(0xFF111111), 'X'),
      'whatsapp' => (
        FontAwesomeIcons.whatsapp,
        const Color(0xFF25D366),
        'WhatsApp',
      ),
      _ => (
        FontAwesomeIcons.globe,
        Theme.of(context).colorScheme.primary,
        'Sitio web',
      ),
    };
    return Tooltip(
      message: label,
      child: Material(
        color: color,
        shape: const CircleBorder(side: BorderSide(color: Colors.white24)),
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

/// Pie del menú: versión y, discreto, el crédito del desarrollador (toca
/// para ver el contacto).
class _VersionFooter extends StatelessWidget {
  const _VersionFooter({required this.onDeveloperTap});

  final VoidCallback onDeveloperTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Row(
          children: [
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) => Text(
                snapshot.hasData ? 'v${snapshot.data!.version}' : '',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onDeveloperTap,
              child: Text(
                'Desarrollado por $kDeveloperName',
                style: TextStyle(
                  color: muted.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
            ),
          ],
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
    final textTheme = Theme.of(context).textTheme;
    final gradient = brandGradient(
      branding.primaryColor,
      secondary: branding.secondaryColor,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          // Cabecera con los colores del canal: logo, nombre y versión.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 120,
                  // Logo subido en el panel; si no hay, el empaquetado en el
                  // APK, la versión de letras blancas (va sobre el degradé).
                  child: branding.logoUrl != null
                      ? Image.network(
                          branding.logoUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Image.asset(
                            FlavorConfig.instance.logoOnDarkAsset,
                          ),
                        )
                      : Image.asset(FlavorConfig.instance.logoOnDarkAsset),
                ),
                const SizedBox(height: 14),
                Text(
                  branding.appName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      snapshot.hasData
                          ? 'Versión ${snapshot.data!.version}'
                          : 'Versión',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'La aplicación oficial de ${branding.appName}.',
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          const _Feature(
            icon: Icons.live_tv_rounded,
            title: 'Señal en vivo',
            text: 'Mira el canal desde donde estés, en tu celular.',
          ),
          const _Feature(
            icon: Icons.newspaper_rounded,
            title: 'Noticias del canal',
            text: 'Entérate de lo último, con destacadas y categorías.',
          ),
          const _Feature(
            icon: Icons.touch_app_rounded,
            title: 'Sin crear cuenta',
            text: 'Abres la app y el canal empieza solo, como prender la tele.',
          ),
          const _Feature(
            icon: Icons.picture_in_picture_alt_rounded,
            title: 'Imagen en imagen',
            text: 'Sigue viendo en una ventana flotante mientras usas otras apps.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openLink(context, kPrivacyUrl, inApp: true),
                  icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                  label: const Text('Privacidad'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openLink(context, kTermsUrl, inApp: true),
                  icon: const Icon(Icons.gavel_rounded, size: 18),
                  label: const Text('Términos'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '© ${DateTime.now().year} ${branding.appName} · '
            'Desarrollado por $kDeveloperName',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Una fila de "Acerca de la app": ícono en cápsula + título + descripción.
class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: scheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
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
          Text(
            kDeveloperName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Desarrollo de apps y plataformas de streaming · Ecuador',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
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
