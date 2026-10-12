import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Una sección navegable del panel (ítem de sidebar + su página).
class DashboardDestination {
  const DashboardDestination({
    required this.icon,
    required this.label,
    required this.pageTitle,
    required this.pageSubtitle,
    required this.bodyBuilder,
    this.actions = const [],
    this.searchHint = '',
    this.showSearch = false,
  });

  final IconData icon;
  final String label;
  final String pageTitle;
  final String pageSubtitle;
  final String searchHint;
  final List<Widget> actions;
  final bool showSearch;

  /// `search` ya viene recortado y en minúsculas.
  final Widget Function(BuildContext context, String search) bodyBuilder;
}

/// Caparazón visual del panel: sidebar (marca + navegación + usuario) +
/// barra superior (título, buscador, acciones) + cuerpo, con navegación
/// real entre [destinations].
class DashboardShell extends StatefulWidget {
  const DashboardShell({
    super.key,
    required this.sidebarIcon,
    required this.appName,
    required this.sidebarTagline,
    required this.destinations,
  });

  final Widget sidebarIcon;
  final String appName;
  final String sidebarTagline;
  final List<DashboardDestination> destinations;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  int _selectedIndex = 0;
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectDestination(int index) {
    setState(() {
      _selectedIndex = index;
      _search = '';
      _searchController.clear();
    });
    if (!(MediaQuery.sizeOf(context).width >= 900)) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final destination = widget.destinations[_selectedIndex];

    return Scaffold(
      key: _scaffoldKey,
      drawer: isWide
          ? null
          : Drawer(
              child: _Sidebar(
                widget: widget,
                selectedIndex: _selectedIndex,
                onSelect: _selectDestination,
              ),
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (isWide)
              _Sidebar(
                widget: widget,
                selectedIndex: _selectedIndex,
                onSelect: _selectDestination,
              ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(
                    showMenuButton: !isWide,
                    onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                    title: destination.pageTitle,
                    subtitle: destination.pageSubtitle,
                    searchHint: destination.searchHint,
                    searchController: _searchController,
                    onSearchChanged: (value) =>
                        setState(() => _search = value.trim().toLowerCase()),
                    actions: destination.actions,
                    showSearch: destination.showSearch,
                  ),
                  Expanded(
                    child: Builder(
                      key: ValueKey(_selectedIndex),
                      builder: (context) =>
                          destination.bodyBuilder(context, _search),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.widget,
    required this.selectedIndex,
    required this.onSelect,
  });

  final DashboardShell widget;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Container(
      width: 264,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          right:
              BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // Solo azul acá a pedido explícito -- igual que la cabecera
                // de "Canal" (tenant_dashboard.dart), no el degradé de
                // marca azul/rojo.
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary,
                    Color.alphaBlend(
                      Colors.black.withValues(alpha: 0.45),
                      scheme.primary,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: widget.sidebarIcon,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.appName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.sidebarTagline,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final (index, destination) in widget.destinations.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _NavItem(
                icon: destination.icon,
                label: destination.label,
                selected: index == selectedIndex,
                onTap: () => onSelect(index),
              ),
            ),
          const Spacer(),
          Divider(
              height: 1, color: scheme.outlineVariant.withValues(alpha: 0.6)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    email.isNotEmpty ? email[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    email,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar sesión',
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  onPressed: () => FirebaseAuth.instance.signOut(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.showMenuButton,
    required this.onMenuTap,
    required this.title,
    required this.subtitle,
    required this.searchHint,
    required this.searchController,
    required this.onSearchChanged,
    required this.actions,
    required this.showSearch,
  });

  final bool showMenuButton;
  final VoidCallback onMenuTap;
  final String title;
  final String subtitle;
  final String searchHint;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final List<Widget> actions;
  final bool showSearch;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isNarrow = MediaQuery.sizeOf(context).width < 720;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          if (showMenuButton) ...[
            IconButton(
                icon: const Icon(Icons.menu_rounded), onPressed: onMenuTap),
            const SizedBox(width: 4),
          ],
          if (!isNarrow)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    )
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          if (showSearch)
            SizedBox(
              width: isNarrow ? 200 : 280,
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: searchHint,
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            searchController.clear();
                            onSearchChanged('');
                          },
                        ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
                ),
              ),
            ),
          for (final action in actions) ...[const SizedBox(width: 12), action],
        ],
      ),
    );
  }
}
