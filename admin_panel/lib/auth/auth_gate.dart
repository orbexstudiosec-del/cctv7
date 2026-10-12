import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../tenant/tenant_branding.dart';
import '../tenant/tenant_dashboard.dart';
import 'login_card.dart';

/// Pantalla de login con la marca del tenant ya aplicada, más verificación
/// de que el usuario autenticado pertenece a este tenant. La garantía real
/// de seguridad vive en las Security Rules (firestore.rules); esto es UX
/// temprana para no dejar entrar a alguien al dashboard equivocado.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.branding});

  final TenantBranding branding;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Fuerza el refresh: si el claim se asignó hace poco, el token en
      // caché todavía no lo trae.
      final tokenResult = await credential.user!.getIdTokenResult(true);
      final tenantId = tokenResult.claims?['tenant_id'] as String?;
      final role = tokenResult.claims?['role'] as String?;

      final belongsHere =
          tenantId == widget.branding.tenantId || role == 'super_admin';
      if (!belongsHere) {
        await FirebaseAuth.instance.signOut();
        throw Exception('Esta cuenta no pertenece a este panel.');
      }
    } catch (e) {
      setState(() => _error = 'No se pudo iniciar sesión: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user != null) {
          return _RoleResolver(branding: widget.branding, user: user);
        }
        return LoginCard(
          title: widget.branding.appName,
          logoUrl: widget.branding.logoUrl,
          logoOnColorUrl: widget.branding.logoForBrandBackground,
          emailController: _emailController,
          passwordController: _passwordController,
          loading: _loading,
          error: _error,
          onSubmit: _signIn,
        );
      },
    );
  }
}

/// Trae el rol del custom claim antes de montar el dashboard: decide qué
/// puede hacer este usuario dentro de su tenant (ver [TenantDashboard]).
/// La garantía real sigue siendo firestore.rules; esto es solo para la UI.
class _RoleResolver extends StatelessWidget {
  const _RoleResolver({required this.branding, required this.user});

  final TenantBranding branding;
  final User user;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<IdTokenResult>(
      future: user.getIdTokenResult(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final role = snapshot.data!.claims?['role'] as String? ?? 'viewer';
        return TenantDashboard(branding: branding, role: role);
      },
    );
  }
}
