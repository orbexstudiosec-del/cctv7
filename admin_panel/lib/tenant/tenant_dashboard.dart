import 'package:flutter/material.dart';

import '../channel/channel_repository.dart';
import '../channel/channel_summary.dart';
import '../channel/widgets/channel_details_dialog.dart';
import '../channel/widgets/channel_preview_card.dart';
import '../channel/widgets/stream_sources_card.dart';
import '../news/news_item.dart';
import '../news/news_page.dart';
import '../news/news_repository.dart';
import '../news/widgets/news_form_dialog.dart';
import '../reports/reports_page.dart';
import '../schedule/schedule_page.dart';
import '../schedule/schedule_repository.dart';
import '../schedule/widgets/schedule_form_dialog.dart';
import '../settings/social_links_page.dart';
import '../shared/theme.dart';
import '../shared/widgets/dashboard_shell.dart';
import 'tenant_branding.dart';

/// Panel del tenant: sidebar + control del canal único en tiempo real.
/// Ya no es una lista de streams (decisión del 2026-10-10 de dejar el
/// modelo SaaS multi-stream) — un tenant tiene un solo canal, que está en
/// vivo o fuera del aire. `role` decide qué puede hacer cada quien (ver
/// firebase/firestore.rules, misma jerarquía ahí reflejada): `viewer`
/// solo lee, `editor`/`tenant_admin` pueden salir al aire, editar detalles
/// y cambiar el enlace de la señal.
class TenantDashboard extends StatelessWidget {
  const TenantDashboard(
      {super.key, required this.branding, required this.role});

  final TenantBranding branding;
  final String role;

  bool get _canManage => role == 'tenant_admin' || role == 'editor';

  @override
  Widget build(BuildContext context) {
    final repository = ChannelRepository();
    final newsRepository = NewsRepository();
    final scheduleRepository = ScheduleRepository();

    return DashboardShell(
      sidebarIcon: branding.logoForBrandBackground != null
          ? Image.network(
              branding.logoForBrandBackground!,
              width: 30,
              height: 30,
              fit: BoxFit.contain,
            )
          : const Icon(Icons.live_tv_rounded, color: Colors.white, size: 24),
      appName: branding.appName,
      sidebarTagline: 'Panel del canal',
      destinations: [
        DashboardDestination(
          icon: Icons.live_tv_rounded,
          label: 'Canal',
          pageTitle: 'Canal',
          pageSubtitle: 'Control de tu transmisión en vivo',
          bodyBuilder: (context, _) => FutureBuilder<void>(
            future: repository.ensureChannel(branding.tenantId),
            builder: (context, ensureSnap) {
              if (ensureSnap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (ensureSnap.hasError) {
                return Center(child: Text('Error: ${ensureSnap.error}'));
              }

              return StreamBuilder<ChannelSummary?>(
                stream: repository.watchChannel(branding.tenantId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data == null) {
                    return const Center(
                      child: Text('No se pudo cargar el canal.'),
                    );
                  }

                  final channel = snapshot.data!;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 820),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HeroBanner(branding: branding),
                            const SizedBox(height: 24),
                            _DashboardStats(
                              tenantId: branding.tenantId,
                              channel: channel,
                              newsRepository: newsRepository,
                            ),
                            const SizedBox(height: 24),
                            ChannelPreviewCard(channel: channel),
                            const SizedBox(height: 24),
                            _ChannelControlCard(
                              channel: channel,
                              tenantId: branding.tenantId,
                              repository: repository,
                              canManage: _canManage,
                            ),
                            const SizedBox(height: 24),
                            StreamSourcesCard(
                              channel: channel,
                              tenantId: branding.tenantId,
                              repository: repository,
                              canManage: _canManage,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        DashboardDestination(
          icon: Icons.campaign_outlined,
          label: 'Noticias',
          pageTitle: 'Noticias',
          pageSubtitle: 'Publicá novedades para tus espectadores',
          showSearch: true,
          searchHint: 'Buscar por título…',
          actions: [
            if (_canManage)
              FilledButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => NewsFormDialog(
                    tenantId: branding.tenantId,
                    repository: newsRepository,
                    brandColor: branding.primaryColor,
                    brandSecondary: branding.secondaryColor,
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nueva noticia'),
              ),
          ],
          bodyBuilder: (context, search) => NewsPage(
            tenantId: branding.tenantId,
            search: search,
            canManage: _canManage,
            canDelete: role == 'tenant_admin',
            brandColor: branding.primaryColor,
            brandSecondary: branding.secondaryColor,
          ),
        ),
        DashboardDestination(
          icon: Icons.calendar_month_outlined,
          label: 'Programación',
          pageTitle: 'Programación',
          pageSubtitle: 'La parrilla semanal que ven tus espectadores',
          actions: [
            if (_canManage)
              FilledButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => ScheduleFormDialog(
                    tenantId: branding.tenantId,
                    repository: scheduleRepository,
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nuevo programa'),
              ),
          ],
          bodyBuilder: (context, _) => SchedulePage(
            tenantId: branding.tenantId,
            repository: scheduleRepository,
            canManage: _canManage,
          ),
        ),
        DashboardDestination(
          icon: Icons.insights_outlined,
          label: 'Reportes',
          pageTitle: 'Reportes',
          pageSubtitle: 'Visitas e instalaciones de la app, día por día',
          bodyBuilder: (context, _) => ReportsPage(
            tenantId: branding.tenantId,
            channelName: branding.appName,
            brandColor: branding.primaryColor,
          ),
        ),
        DashboardDestination(
          icon: Icons.share_outlined,
          label: 'Redes sociales',
          pageTitle: 'Redes sociales',
          pageSubtitle: 'Enlaces que aparecen en el menú de la app',
          bodyBuilder: (context, _) => SocialLinksPage(
            tenantId: branding.tenantId,
            canManage: _canManage,
          ),
        ),
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.branding});

  final TenantBranding branding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        // Solo azul acá a pedido explícito -- el degradé azul/rojo de marca
        // (brandGradient) se usa en otros lugares, pero esta cabecera va
        // con tonos del color primario solamente.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            branding.primaryColor,
            Color.alphaBlend(
              Colors.black.withValues(alpha: 0.45),
              branding.primaryColor,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: branding.primaryColor.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola de nuevo',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  branding.appName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Controlá tu transmisión en vivo desde acá.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.live_tv_rounded,
                color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }
}

/// Cifras reales del canal (nada inventado/simulado): el estado viene del
/// doc del canal, tiempo en vivo se calcula desde `startedAt`, y el conteo
/// de noticias sale de su propio repositorio -- cada tarjeta se resuelve
/// de forma independiente para que una falla en una no tumbe a las demás.
class _DashboardStats extends StatelessWidget {
  const _DashboardStats({
    required this.tenantId,
    required this.channel,
    required this.newsRepository,
  });

  final String tenantId;
  final ChannelSummary channel;
  final NewsRepository newsRepository;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _StatCard(
          icon: channel.isLive
              ? Icons.sensors_rounded
              : Icons.pause_circle_outline_rounded,
          iconColor: channel.isLive ? Colors.red : null,
          value: channel.isLive ? 'En vivo' : 'Fuera del aire',
          label: 'Estado actual',
        ),
        _StatCard(
          icon: Icons.schedule_rounded,
          value: _liveDuration(channel),
          label: 'Tiempo en vivo',
        ),
        StreamBuilder<List<NewsItem>>(
          stream: newsRepository.watchNews(tenantId),
          builder: (context, snapshot) => _StatCard(
            icon: Icons.campaign_outlined,
            value: snapshot.hasData
                ? '${snapshot.data!.where((n) => n.published).length}'
                : '—',
            label: 'Noticias publicadas',
          ),
        ),
      ],
    );
  }

  String _liveDuration(ChannelSummary channel) {
    if (!channel.isLive || channel.startedAt == null) return '—';
    final elapsed =
        DateTime.now().toUtc().difference(channel.startedAt!.toUtc());
    if (elapsed.isNegative) return '—';
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes % 60;
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 180,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: floatingShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor ?? scheme.primary),
          const SizedBox(height: 14),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _ChannelControlCard extends StatelessWidget {
  const _ChannelControlCard({
    required this.channel,
    required this.tenantId,
    required this.repository,
    required this.canManage,
  });

  final ChannelSummary channel;
  final String tenantId;
  final ChannelRepository repository;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLive = channel.isLive;
    final statusColor = isLive ? Colors.red : scheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: floatingShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: isLive
                      ? [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isLive ? 'EN VIVO' : 'FUERA DEL AIRE',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 0.5,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            channel.title.isEmpty ? '(sin título todavía)' : channel.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (channel.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              channel.description,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
          if (canManage) ...[
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  // Sin enlace no hay nada que poner al aire; apagar
                  // siempre se puede.
                  onPressed: isLive || channel.hasAnySource
                      ? () => repository.setLive(tenantId, !isLive)
                      : null,
                  style: isLive
                      ? FilledButton.styleFrom(backgroundColor: scheme.error)
                      : null,
                  icon: Icon(
                    isLive ? Icons.stop_circle_outlined : Icons.sensors_rounded,
                    size: 18,
                  ),
                  label:
                      Text(isLive ? 'Finalizar transmisión' : 'Salir al aire'),
                ),
                OutlinedButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => ChannelDetailsDialog(
                      tenantId: tenantId,
                      repository: repository,
                      existing: channel,
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar detalles'),
                ),
                // El enlace de la señal ahora se edita en la tarjeta
                // "Servidores de transmisión" (principal + adicionales).
              ],
            ),
          ],
        ],
      ),
    );
  }
}
