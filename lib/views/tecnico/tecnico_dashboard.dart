import 'package:clima_pro/models/solicitud.dart';
import 'package:clima_pro/services/auth_service.dart';
import 'package:clima_pro/services/requests_service.dart';
import 'package:flutter/material.dart';

// ⭐ Necesario para abrir Google Maps externo
import 'package:url_launcher/url_launcher.dart';

class TecnicoDashboard extends StatelessWidget {
  const TecnicoDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentFbUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('No autenticado')));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trabajos del Técnico'),
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(54),
            child: _StyledTabs(),
          ),
          actions: [
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: () => AuthService.instance.signOut(),
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF6F8FB), Color(0xFFF1F5F9)],
            ),
          ),
          child: TabBarView(
            children: [
              _PendientesTab(tecnicoId: uid),
              _MisTrabajosTab(tecnicoId: uid),
            ],
          ),
        ),
      ),
    );
  }
}

class _StyledTabs extends StatelessWidget {
  const _StyledTabs();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const double kTabsHeight = 70;

    return PreferredSize(
      preferredSize: const Size.fromHeight(kTabsHeight),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Container(
          height: kTabsHeight - 16,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF3F7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            isScrollable: false,
            labelPadding: const EdgeInsets.symmetric(horizontal: 8),
            labelStyle: theme.textTheme.labelLarge,
            unselectedLabelColor: Colors.blueGrey,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(
                height: 56,
                iconMargin: EdgeInsets.only(bottom: 4),
                icon: Icon(Icons.inbox_outlined),
                text: 'Pendientes',
              ),
              Tab(
                height: 56,
                iconMargin: EdgeInsets.only(bottom: 4),
                icon: Icon(Icons.handyman_outlined),
                text: 'Mis trabajos',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ------------------------- PENDIENTES -------------------------
class _PendientesTab extends StatelessWidget {
  const _PendientesTab({required this.tecnicoId});
  final String tecnicoId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Solicitud>>(
      stream: RequestsService.instance.pendientesParaTecnico(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data ?? [];
        if (data.isEmpty) {
          return const _EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Sin solicitudes pendientes',
            subtitle: 'Cuando haya una nueva, aparecerá aquí.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          itemCount: data.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final s = data[i];
            return _PendingJobCard(
              title: _titleFromTipo(s.tipo),
              description: s.descripcion,
              address: s.direccion,
              onTake: () async {
                await RequestsService.instance.asignarme(s.id, tecnicoId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Trabajo asignado a ti')),
                  );
                }
              },
              onMore: () {
                _showMoreSheet(context, s);
              },
            );
          },
        );
      },
    );
  }

  void _showMoreSheet(BuildContext context, Solicitud s) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: const Text('Abrir en mapas'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _abrirEnMapas(context, s); // ⭐ usa lat/lng o dirección
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: const Text('Llamar al cliente'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: integrar tel:
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PendingJobCard extends StatelessWidget {
  final String title;
  final String description;
  final String address;
  final VoidCallback onTake;
  final VoidCallback onMore;

  const _PendingJobCard({
    required this.title,
    required this.description,
    required this.address,
    required this.onTake,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1.5,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.request_page_outlined,
                  color: Color(0xFF475569)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.place_outlined,
                          size: 16, color: Colors.blueGrey.shade500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.blueGrey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: onTake,
                        child: const Text('Tomar'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: onMore,
                        icon: const Icon(Icons.more_horiz),
                        label: const Text('Más'),
                      ),
                    ],
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

/// ------------------------- MIS TRABAJOS -------------------------
class _MisTrabajosTab extends StatelessWidget {
  const _MisTrabajosTab({required this.tecnicoId});
  final String tecnicoId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Solicitud>>(
      stream: RequestsService.instance.misTrabajos(tecnicoId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data ?? [];
        if (data.isEmpty) {
          return const _EmptyState(
            icon: Icons.handyman_outlined,
            title: 'Sin trabajos asignados',
            subtitle: 'Cuando tomes uno, aparecerá aquí.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          itemCount: data.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final s = data[i];
            return _MyJobCard(
              title: _titleFromTipo(s.tipo),
              description: s.descripcion,
              address: s.direccion,
              estado: s.estado,
              onVerMapa: () => _abrirEnMapas(context, s), // ⭐
              onStart: s.estado == 'asignada'
                  ? () => RequestsService.instance.iniciarTrabajo(s.id, tecnicoId)
                  : null,
              onComplete: s.estado == 'en_proceso'
                  ? () => RequestsService.instance.completar(s.id, tecnicoId)
                  : null,
            );
          },
        );
      },
    );
  }
}

class _MyJobCard extends StatelessWidget {
  final String title;
  final String description;
  final String address;
  final String estado;
  final VoidCallback? onStart;
  final VoidCallback? onComplete;
  final VoidCallback? onVerMapa; // ⭐

  const _MyJobCard({
    required this.title,
    required this.description,
    required this.address,
    required this.estado,
    required this.onStart,
    required this.onComplete,
    this.onVerMapa,
  });

  Color get _chipBg => switch (estado) {
        'asignada' => const Color(0xFFE0F2FE),
        'en_proceso' => const Color(0xFFEDE9FE),
        'completada' => const Color(0xFFE8F5E9),
        _ => const Color(0xFFF1F5F9),
      };

  Color get _chipFg => switch (estado) {
        'asignada' => const Color(0xFF0369A1),
        'en_proceso' => const Color(0xFF6D28D9),
        'completada' => const Color(0xFF1B5E20),
        _ => const Color(0xFF475569),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1.5,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado con chip
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _chipBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(estado,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: _chipFg)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(description,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.blueGrey)),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.place_outlined,
                    size: 16, color: Colors.blueGrey.shade500),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.blueGrey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // ⭐ Botón "Ver en mapa"
            if (onVerMapa != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onVerMapa,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Ver en mapa'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),

            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Iniciar'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onComplete,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Completar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ------------------------- UTILIDADES -------------------------
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.blueGrey.shade300),
            const SizedBox(height: 10),
            Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.blueGrey),
            ),
          ],
        ),
      ),
    );
  }
}

String _titleFromTipo(String t) => switch (t) {
      'instalacion' => 'Instalación',
      'mantenimiento' => 'Mantenimiento',
      'reparacion' => 'Reparación',
      _ => t,
    };

/// ⭐ Función auxiliar para abrir Google Maps con lat/lng o dirección
Future<void> _abrirEnMapas(BuildContext context, Solicitud s) async {
  Uri url;

  if (s.latitud != null && s.longitud != null) {
    // Usamos coordenadas exactas
    url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${s.latitud},${s.longitud}',
    );
  } else if (s.direccion.isNotEmpty) {
    // Fallback: buscar por dirección en texto
    final q = Uri.encodeComponent(s.direccion);
    url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$q',
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No hay dirección para abrir en mapas')),
    );
    return;
  }

  if (!await canLaunchUrl(url)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir la aplicación de mapas')),
    );
    return;
  }

  await launchUrl(url, mode: LaunchMode.externalApplication);
}