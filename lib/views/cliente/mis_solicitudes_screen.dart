import 'package:clima_pro/models/solicitud.dart';
import 'package:clima_pro/services/auth_service.dart';
import 'package:clima_pro/services/requests_service.dart';
import 'package:clima_pro/views/home/home_cliente.dart';
import 'package:flutter/material.dart';

import 'package:clima_pro/views/home/avisos_screen.dart';
import 'package:clima_pro/views/home/perfil_screen.dart';
import 'package:clima_pro/widgets/cliente_bottom_nav.dart';

class MisSolicitudesScreen extends StatefulWidget {
  const MisSolicitudesScreen({super.key});

  static const routeName = '/mis-solicitudes';

  @override
  State<MisSolicitudesScreen> createState() => _MisSolicitudesScreenState();
}

class _MisSolicitudesScreenState extends State<MisSolicitudesScreen> {
  bool _verTodoHistorial = false;
  bool _accionEnCurso = false;

  Color _estadoColor(String e) {
    switch (e) {
      case 'pendiente':
        return Colors.amber;
      case 'asignada':
        return Colors.blue;
      case 'en_proceso':
        return Colors.deepPurple;
      case 'completada':
        return Colors.green;
      case 'cancelada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _titleFromTipo(String t) {
    switch (t) {
      case 'instalacion':
        return 'Instalación';
      case 'mantenimiento':
        return 'Mantenimiento';
      case 'reparacion':
        return 'Reparación';
      default:
        return t;
    }
  }

  String _mesCorto(int m) => [
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
      ][m - 1];

  String _fechaFmt(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    return '$dd ${_mesCorto(d.month)} ${d.year}';
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

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeCliente()),
    );
  }

  // ------- Acciones: Modificar / Cancelar ----------------

  Future<void> _onCancelar(Solicitud s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar servicio'),
        content: const Text(
          '¿Estás seguro de que deseas cancelar esta solicitud? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _accionEnCurso = true); // <-- empieza overlay

    try {
      await RequestsService.instance.cancelSolicitudCliente(s.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud cancelada correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cancelar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _accionEnCurso = false); // <-- quita overlay
      }
    }
  }

  Future<void> _onModificar(Solicitud s) async {
    // Solo permite modificar si sigue pendiente
    if (s.estado != 'pendiente') return;

    final DateTime now = DateTime.now();
    DateTime fechaBase = s.fechaPreferida ?? now;

    // 1) Elegir nueva fecha
    final nuevaFecha = await showDatePicker(
      context: context,
      initialDate: fechaBase.isBefore(now) ? now : fechaBase,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
      helpText: 'Selecciona la nueva fecha',
    );

    if (nuevaFecha == null) return;

    // 2) Elegir nueva hora
    final nuevaHora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(fechaBase),
      helpText: 'Selecciona la nueva hora',
    );

    if (nuevaHora == null) return;

    final fechaCompleta = DateTime(
      nuevaFecha.year,
      nuevaFecha.month,
      nuevaFecha.day,
      nuevaHora.hour,
      nuevaHora.minute,
    );

    setState(() => _accionEnCurso = true); // ← comienza overlay

    try {
      await RequestsService.instance.reprogramarSolicitud(
        s.id,
        fechaCompleta,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Solicitud actualizada a ${_fechaFmt(fechaCompleta)} '
            'a las ${_horaFmt(fechaCompleta)}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al modificar: $e')),
      );
    } finally {
      if (mounted) setState(() => _accionEnCurso = false); // ← termina overlay
    }
  }

  // ------- Historial: ver detalles / eliminar ----------------

  void _abrirDetalleHistorial(Solicitud s) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetalleHistorialScreen(
          solicitudId: s.id,
          titulo: _titleFromTipo(s.tipo),
          tecnico: _tecnicoDe(s),
          fecha: s.fechaPreferida,
          descripcion: s.descripcion,
          estado: s.estado,
        ),
      ),
    );
  }

  Future<void> _eliminarDeHistorial(Solicitud s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ocultar del historial'),
        content: const Text(
          '¿Quieres ocultar este servicio de tu historial?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ocultar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _accionEnCurso = true);

    try {
      await RequestsService.instance.ocultarSolicitudCliente(s.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servicio ocultado del historial.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al ocultar: $e')),
      );
    } finally {
      if (mounted) setState(() => _accionEnCurso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentFbUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Usuario no autenticado')),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // --- CONTENIDO PRINCIPAL ---
          StreamBuilder<List<Solicitud>>(
            stream: RequestsService.instance.mySolicitudes(uid),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                // carga inicial
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Cargando solicitudes...'),
                    ],
                  ),
                );
              }

              final data = (snap.data ?? []).toList();

              // Filtra las que NO estén ocultas para el cliente
              data.removeWhere((s) {
                try {
                  final oculto = (s as dynamic).ocultaCliente == true;
                  return oculto;
                } catch (_) {
                  return false;
                }
              });

              // Próximos: pendiente o asignada
              final proximos = data
                  .where((s) =>
                      s.estado == 'pendiente' || s.estado == 'asignada')
                  .toList()
                ..sort((a, b) {
                  final fa = a.fechaPreferida ?? DateTime.now();
                  final fb = b.fechaPreferida ?? DateTime.now();
                  return fa.compareTo(fb);
                });

              // Historial: completadas
              final historial =
                  data.where((s) => s.estado == 'completada').toList()
                    ..sort((a, b) {
                      final fa = a.fechaPreferida ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      final fb = b.fechaPreferida ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      return fb.compareTo(fa); // más recientes primero
                    });

              if (proximos.isEmpty && historial.isEmpty) {
                return const Center(
                  child: Text(
                    'Aún no tienes solicitudes registradas.',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              final historialVisible =
                  _verTodoHistorial ? historial : historial.take(3).toList();
              final ocultos = historial.length - historialVisible.length;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  Text(
                    'Mi Agenda',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),

                  // ------------ PRÓXIMOS SERVICIOS -----------------
                  if (proximos.isNotEmpty) ...[
                    Text(
                      'PRÓXIMOS SERVICIOS',
                      style:
                          Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: Colors.grey[700],
                                letterSpacing: .4,
                              ),
                    ),
                    const SizedBox(height: 10),
                    ...proximos.map((s) {
                      final puedeGestionar = s.estado == 'pendiente';
                      return _ProximoCard(
                        titulo: _titleFromTipo(s.tipo),
                        tecnico: _tecnicoDe(s),
                        fecha: s.fechaPreferida,
                        estado: s.estado,
                        colorEstado: _estadoColor(s.estado),
                        descripcion: s.descripcion,
                        puedeGestionar: puedeGestionar,
                        onModificar:
                            puedeGestionar ? () => _onModificar(s) : null,
                        onCancelar:
                            puedeGestionar ? () => _onCancelar(s) : null,
                      );
                    }),
                    const SizedBox(height: 20),
                  ],

                  // ------------ HISTORIAL -----------------
                  Text(
                    'HISTORIAL',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.grey[700],
                          letterSpacing: .4,
                        ),
                  ),
                  const SizedBox(height: 10),
                  if (historial.isEmpty)
                    Text(
                      'Sin servicios completados aún.',
                      style: TextStyle(color: Colors.grey[700]),
                    )
                  else ...[
                    ...historialVisible.map(
                      (s) => _HistorialItem(
                        solicitud: s,
                        titulo: _titleFromTipo(s.tipo),
                        tecnico: _tecnicoDe(s),
                        fecha: s.fechaPreferida,
                        descripcion: s.descripcion,
                        estado: s.estado,
                        onVerDetalles: () => _abrirDetalleHistorial(s),
                        onEliminar: () => _eliminarDeHistorial(s),
                      ),
                    ),
                    if (ocultos > 0)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _verTodoHistorial = !_verTodoHistorial;
                            });
                          },
                          child: Text(
                            _verTodoHistorial
                                ? 'Ver menos historial'
                                : 'Ver más historial ($ocultos)',
                          ),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),

          // --- OVERLAY DE CARGA MIENTRAS HACES ACCIONES ---
          if (_accionEnCurso)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text(
                      'Aplicando cambios...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: ClienteBottomNav(
        currentIndex: 1, // 1 = Agenda
        onTap: (index) {
          if (index == 1) return; // ya estás aquí

          if (index == 0) {
            _goHome();
            return;
          }
          if (index == 2) {
            Navigator.pushReplacementNamed(
              context,
              AvisosScreen.routeName,
            );
            return;
          }
          if (index == 3) {
            Navigator.pushReplacementNamed(
              context,
              PerfilScreen.routeName,
            );
            return;
          }
        },
      ),
    );
  }
}

/// Card para “Próximos Servicios”
class _ProximoCard extends StatelessWidget {
  final String titulo;
  final String? tecnico;
  final DateTime? fecha;
  final String estado;
  final Color colorEstado;
  final String? descripcion;

  final bool puedeGestionar;
  final VoidCallback? onModificar;
  final VoidCallback? onCancelar;

  const _ProximoCard({
    required this.titulo,
    required this.tecnico,
    required this.fecha,
    required this.estado,
    required this.colorEstado,
    required this.descripcion,
    required this.puedeGestionar,
    this.onModificar,
    this.onCancelar,
  });

  String _fechaFmt(DateTime d) {
    final meses = [
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 1),
            blurRadius: 4,
            color: Colors.black.withOpacity(.03),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título + estado
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorEstado.withOpacity(.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colorEstado.withOpacity(.8)),
                ),
                child: Text(
                  estado,
                  style: TextStyle(
                    color: colorEstado,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (tecnico != null)
            Text(
              'Técnico: $tecnico',
              style: TextStyle(color: Colors.grey[700]),
            ),
          const SizedBox(height: 8),
          // Fecha y hora
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                fecha == null ? 'Fecha por confirmar' : _fechaFmt(fecha!),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.access_time, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                fecha == null ? '--:--' : _horaFmt(fecha!),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
          if ((descripcion ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              descripcion!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[800]),
            ),
          ],

          // Botones Modificar / Cancelar
          if (puedeGestionar &&
              (onModificar != null || onCancelar != null)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onModificar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE3F2FD),
                      foregroundColor: const Color(0xFF1565C0),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Modificar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onCancelar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFEBEE),
                      foregroundColor: const Color(0xFFC62828),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Ítem de la lista de “Historial”
class _HistorialItem extends StatelessWidget {
  final Solicitud solicitud;
  final String titulo;
  final String? tecnico;
  final DateTime? fecha;
  final String? descripcion;
  final String estado;
  final VoidCallback onVerDetalles;
  final VoidCallback onEliminar;

  const _HistorialItem({
    required this.solicitud,
    required this.titulo,
    required this.tecnico,
    required this.fecha,
    required this.descripcion,
    required this.estado,
    required this.onVerDetalles,
    required this.onEliminar,
  });

  String _fechaFmt(DateTime d) {
    final meses = [
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          isThreeLine: true,
          title: Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tecnico != null)
                Text(
                  'Técnico: $tecnico',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    fecha == null ? 'Fecha no disponible' : _fechaFmt(fecha!),
                  ),
                ],
              ),
            ],
          ),
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onVerDetalles,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Ver detalles'),
              ),
              TextButton(
                onPressed: onEliminar,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: Colors.red,
                ),
                child: const Text('Ocultar'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

/// Pantalla de detalle + calificación del técnico
class DetalleHistorialScreen extends StatefulWidget {
  final String solicitudId;
  final String titulo;
  final String? tecnico;
  final DateTime? fecha;
  final String? descripcion;
  final String estado;

  const DetalleHistorialScreen({
    super.key,
    required this.solicitudId,
    required this.titulo,
    required this.tecnico,
    required this.fecha,
    required this.descripcion,
    required this.estado,
  });

  @override
  State<DetalleHistorialScreen> createState() => _DetalleHistorialScreenState();
}

class _DetalleHistorialScreenState extends State<DetalleHistorialScreen> {
  int _rating = 0;
  final _commentCtrl = TextEditingController();
  bool _sending = false;

  String _fechaFmt(DateTime d) {
    final meses = [
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

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviarOpinion() async {
    setState(() => _sending = true);

    try {
      await RequestsService.instance.guardarOpinionCliente(
        widget.solicitudId,
        _rating,
        _commentCtrl.text.trim(),
      );

      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Gracias por tu opinión!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar opinión: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fechaStr =
        widget.fecha == null ? 'Fecha no disponible' : _fechaFmt(widget.fecha!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del servicio'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card detalle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.tecnico != null)
                    Text(
                      'Técnico: ${widget.tecnico}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(fechaStr),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('Estado: ${widget.estado}'),
                    ],
                  ),
                  if ((widget.descripcion ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.descripcion!,
                      style: TextStyle(color: Colors.grey[800]),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Califica al técnico',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            // Estrellas
            Row(
              children: List.generate(5, (index) {
                final filled = index < _rating;
                return IconButton(
                  icon: Icon(
                    filled ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: () {
                    setState(() => _rating = index + 1);
                  },
                );
              }),
            ),

            const SizedBox(height: 8),
            TextField(
              controller: _commentCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Comentario (opcional)',
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sending ? null : _enviarOpinion,
                child: _sending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enviar opinión'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}