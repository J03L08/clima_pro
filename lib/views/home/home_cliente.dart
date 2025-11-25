import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../cliente/nueva_solicitud_screen.dart';
import '../cliente/mis_solicitudes_screen.dart';
import 'package:clima_pro/services/auth_service.dart';
import 'package:clima_pro/services/requests_service.dart';
import 'package:clima_pro/models/solicitud.dart';
import 'package:clima_pro/views/home/avisos_screen.dart';
import 'package:clima_pro/views/home/perfil_screen.dart';
import 'package:clima_pro/widgets/cliente_bottom_nav.dart';

class HomeCliente extends StatefulWidget {
  const HomeCliente({super.key});

  @override
  State<HomeCliente> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeCliente> {
  int unreadNotifications = 3;

  void _goNuevaSolicitud({String? tipo}) {
    Navigator.of(context).pushNamed(
      NuevaSolicitudScreen.routeName,
      arguments: tipo == null ? null : {'tipo': tipo},
    );
  }

  void _goMisSolicitudes() {
    Navigator.of(context).pushNamed(MisSolicitudesScreen.routeName);
  }

  // ---- Helpers ----------------------------------------------------------------

  String _titleFromTipo(String t) => switch (t) {
        'instalacion' => 'Instalación',
        'mantenimiento' => 'Mantenimiento',
        'reparacion' => 'Reparación',
        _ => t,
      };

  Color _estadoColor(String e) => switch (e) {
        'pendiente' => Colors.amber,
        'asignada' => Colors.blue,
        'en_proceso' => Colors.deepPurple,
        'completada' => Colors.green,
        'cancelada' => Colors.red,
        _ => Colors.grey,
      };

  String _fechaFmt(DateTime d) {
    const meses = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic'
    ];
    final dd = d.day.toString().padLeft(2, '0');
    return '$dd ${meses[d.month - 1]} ${d.year}';
  }

  String _horaFmt(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final suf = d.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $suf';
  }

  String? _tecnicoDe(Solicitud s) {
    try {
      if ((s as dynamic).tecnico != null) {
        final name =
            (((s as dynamic).tecnico)['nombre'] ?? '').toString().trim();
        if (name.isNotEmpty) return name;
      }
    } catch (_) {}
    try {
      if ((s as dynamic).tecnicoNombre != null) {
        final name = ((s as dynamic).tecnicoNombre ?? '').toString().trim();
        if (name.isNotEmpty) return name;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentFbUser;
    final uid = user?.uid;

    // Nombre dinámico para el saludo
    final displayName = user?.displayName?.trim();
    final nombre = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : (user?.email?.split('@').first ?? 'Usuario');

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tarjeta de saludo
          Container(
            decoration: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "¡Hola, $nombre!",
                  style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text("¿Qué servicio necesitas hoy?",
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () => _goNuevaSolicitud(),
                  icon: const Icon(Icons.add, color: Colors.blue),
                  label: const Text("Solicitar Servicio",
                      style: TextStyle(color: Colors.blue)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Servicios Rápidos
          const Text("Servicios Rápidos",
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _quickButton(
                icon: Icons.build,
                label: "Instalación",
                color: Colors.greenAccent,
                onTap: () => _goNuevaSolicitud(tipo: 'instalacion'),
              ),
              const SizedBox(width: 12),
              _quickButton(
                icon: FontAwesomeIcons.screwdriverWrench,
                label: "Reparación",
                color: Colors.amberAccent,
                onTap: () => _goNuevaSolicitud(tipo: 'reparacion'),
              ),
              const SizedBox(width: 12),
              _quickButton(
                icon: Icons.settings,
                label: "Mantenimiento",
                color: Colors.blueAccent,
                onTap: () => _goNuevaSolicitud(tipo: 'mantenimiento'),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Próximas Citas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Próximas Citas",
                  style: TextStyle(fontWeight: FontWeight.w600)),
              TextButton(
                  onPressed: _goMisSolicitudes,
                  child: const Text("Ver todas")),
            ],
          ),
          const SizedBox(height: 8),

          if (uid == null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(16),
              ),
              child:
                  const Text('Inicia sesión para ver tus próximas citas'),
            )
          else
            StreamBuilder<List<Solicitud>>(
              stream: RequestsService.instance.mySolicitudes(uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final all = (snap.data ?? []);

                final proximas = all
                    .where((s) =>
                        s.estado == 'pendiente' || s.estado == 'asignada')
                    .toList()
                  ..sort((a, b) {
                    final fa = a.fechaPreferida;
                    final fb = b.fechaPreferida;
                    if (fa == null && fb == null) return 0;
                    if (fa == null) return 1;
                    if (fb == null) return -1;
                    return fa.compareTo(fb);
                  });

                if (proximas.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border:
                          Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                        'No tienes próximas citas por ahora.'),
                  );
                }

                return Column(
                  children: proximas.map((s) {
                    final color = _estadoColor(s.estado).withOpacity(.12);
                    final textColor = _estadoColor(s.estado);
                    final tecnico = _tecnicoDe(s);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _titleFromTipo(s.tipo),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (tecnico != null)
                                  Text(
                                    "Técnico: $tecnico",
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600]),
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                        Icons.calendar_today_outlined,
                                        size: 14,
                                        color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      s.fechaPreferida == null
                                          ? 'Por confirmar'
                                          : _fechaFmt(
                                              s.fechaPreferida!),
                                      style: const TextStyle(
                                          fontSize: 13),
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.access_time,
                                        size: 14,
                                        color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      s.fechaPreferida == null
                                          ? '--:--'
                                          : _horaFmt(
                                              s.fechaPreferida!),
                                      style: const TextStyle(
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child: Text(
                              s.estado,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),

      bottomNavigationBar: ClienteBottomNav(
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            _goMisSolicitudes();
            return;
          }
          if (index == 2) {
            Navigator.of(context)
                .pushNamed(AvisosScreen.routeName);
            return;
          }
          if (index == 3) {
            Navigator.of(context)
                .pushNamed(PerfilScreen.routeName);
            return;
          }
        },
      ),
    );
  }

  Widget _quickButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withOpacity(0.2),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}