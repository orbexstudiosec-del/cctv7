import 'package:flutter/material.dart';

import '../shared/theme.dart';

/// Pantalla de login con la marca del tenant. En pantallas anchas se
/// parte en dos: panel de marca a la izquierda, formulario a la derecha;
/// en angostas solo se ve el formulario centrado.
class LoginCard extends StatelessWidget {
  const LoginCard({
    super.key,
    required this.title,
    required this.emailController,
    required this.passwordController,
    required this.loading,
    required this.error,
    required this.onSubmit,
    this.logoUrl,
    this.logoOnColorUrl,
    this.tagline = 'Panel de administración',
  });

  final String title;
  final String tagline;
  final String? logoUrl;

  /// Variante del logo para fondo de color de marca (degradé) — cae a
  /// [logoUrl] si no se pasa.
  final String? logoOnColorUrl;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.sizeOf(context).width >= 860;

    final form = _LoginForm(
      title: title,
      logoUrl: logoUrl,
      showBrandHeader: !isWide,
      emailController: emailController,
      passwordController: passwordController,
      loading: loading,
      error: error,
      onSubmit: onSubmit,
    );

    if (!isWide) {
      return Scaffold(
        backgroundColor: scheme.surfaceContainerLow,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: form,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            // Panel de marca negro con el logo oficial (antes era el
            // degradé de marca con un ícono genérico).
            child: Container(
              color: const Color(0xFF0A0A0E),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LogoBadge(
                        logoUrl: logoOnColorUrl ?? logoUrl,
                        fallbackAsset: kLogoOnDarkAsset,
                        height: 240,
                      ),
                      const SizedBox(height: 36),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        tagline,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: scheme.surfaceContainerLow,
              child: Center(child: form),
            ),
          ),
        ],
      ),
    );
  }
}

/// Logo oficial empaquetado (copia de viewer_app/assets/branding/), para
/// cuando el canal todavía no subió uno desde el panel.
const kLogoOnDarkAsset = 'assets/branding/canal7_logo_dark.png'; // letras blancas
const kLogoAsset = 'assets/branding/canal7_logo.png'; // letras negras

/// El logo real de un tenant suele ser un wordmark ancho, no un ícono
/// cuadrado — por eso esto no fuerza un contenedor cuadrado (lo cortaría).
/// Sin marco/fondo: el PNG trae su propia transparencia.
class _LogoBadge extends StatelessWidget {
  const _LogoBadge({
    required this.logoUrl,
    required this.fallbackAsset,
    required this.height,
  });

  final String? logoUrl;
  final String fallbackAsset;
  final double height;

  @override
  Widget build(BuildContext context) {
    final asset = Image.asset(fallbackAsset, height: height, fit: BoxFit.contain);
    if (logoUrl == null) return asset;
    return Image.network(
      logoUrl!,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) => asset,
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.title,
    required this.logoUrl,
    required this.showBrandHeader,
    required this.emailController,
    required this.passwordController,
    required this.loading,
    required this.error,
    required this.onSubmit,
  });

  final String title;
  final String? logoUrl;
  final bool showBrandHeader;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: floatingShadow(context),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showBrandHeader) ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _LogoBadge(
                    logoUrl: logoUrl,
                    fallbackAsset: kLogoAsset,
                    height: 110,
                  ),
                ),
              ),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
            ] else ...[
              Text('Hola de nuevo',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Inicia sesión para continuar',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 28),
            ],
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Correo',
                prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
              ),
              obscureText: true,
              onSubmitted: (_) => onSubmit(),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 18, color: scheme.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        error!,
                        style: TextStyle(color: scheme.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: loading ? null : onSubmit,
              child: loading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Entrar'),
            ),
          ],
        ),
      ),
    );
  }
}
