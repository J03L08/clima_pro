import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:clima_pro/services/auth_service.dart';
import 'package:clima_pro/views/tecnico/tecnico_dashboard.dart';

class HomeTecnico extends StatefulWidget {
  const HomeTecnico({super.key});

  @override
  State<HomeTecnico> createState() => _HomeTecnicoState();
}

class _HomeTecnicoState extends State<HomeTecnico> {
  String _nombreTecnico = 'Técnico';

  int _pendientes = 0;
  int _hoy = 0;
  int _mes = 0;

  bool _cargando = true;
  String? _error;

  final List<_TrabajoTecnico> _agendaHoy = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _error = null;
      _agendaHoy.clear();
    });

    try {
      final fbUser = AuthService.instance.currentFbUser;
      if (fbUser == null) {
        setState(() {
          _error = 'No autenticado';
          _cargando = false;
        });
        return;
      }

      final uid = fbUser.uid;
      final db = FirebaseFirestore.instance;

      // ── 1. Nombre del técnico ──
      final userSnap = await db.collection('users').doc(uid).get();
      final userData = userSnap.data();
      final nombre = (userData?['nombre'] ?? 'Técnico').toString();

      final now = DateTime.now();
      final inicioHoy = DateTime(now.year, now.month, now.day);
      final finHoy = inicioHoy.add(const Duration(days: 1));
      final inicioMes = DateTime(now.year, now.month, 1);
      final inicioMesSiguiente =
          (now.month == 12) ? DateTime(now.year + 1, 1, 1) : DateTime(now.year, now.month + 1, 1);

      // ── 2. Todas las requests del técnico ──
      final qs = await db
          .collection('requests')
          .where('tecnicoAsignadoId', isEqualTo: uid)
          .get();

      int pendientes = 0;
      int hoy = 0;
      int mes = 0;

      final List<_TrabajoTecnico> agendaHoy = [];

      for (final doc in qs.docs) {
        final data = doc.data();

        final String estado = (data['estado'] ?? 'pendiente').toString();

        final Timestamp? ts = data['fechaPreferida'] as Timestamp?;
        final DateTime? fecha = ts?.toDate();

        final String direccion = (data['direccion'] ?? '').toString();
        final String titulo = (data['tipo'] ?? 'Servicio').toString();
        final String clienteId = (data['clienteId'] ?? '').toString();
        String clienteNombre = 'Cliente';

        if (clienteId.isNotEmpty) {
          try {
            final userSnap = await FirebaseFirestore.instance
                .collection('users')
                .doc(clienteId)
                .get();

            final userData = userSnap.data();
            // IMPORTANTE: usa el mismo campo donde guardas el nombre en EditPerfil
            clienteNombre = (userData?['nombre'] ?? 'Cliente').toString();
          } catch (_) {
            // si no existe el usuario, se queda como "Cliente"
          }
        }

        final double? latitud =
            (data['latitud'] is num) ? (data['latitud'] as num).toDouble() : null;
        final double? longitud =
            (data['longitud'] is num) ? (data['longitud'] as num).toDouble() : null;

        // 2.1 Pendientes (cualquier fecha, excepto completada/cancelada)
        if (estado != 'completada' && estado != 'cancelada') {
          pendientes++;
        }

        // 2.2 Servicios del mes actual
        if (fecha != null &&
            !fecha.isBefore(inicioMes) &&
            fecha.isBefore(inicioMesSiguiente)) {
          mes++;
        }

        // 2.3 Servicios de hoy
        if (fecha != null &&
            !fecha.isBefore(inicioHoy) &&
            fecha.isBefore(finHoy)) {
          hoy++;

          // Agenda de hoy: solo pendiente/asignada
          if (estado == 'pendiente' || estado == 'asignada') {
            agendaHoy.add(
              _TrabajoTecnico(
                id: doc.id,
                clienteId: clienteId,
                clienteNombre: clienteNombre,
                titulo: titulo,
                direccion: direccion,
                estado: estado,
                fechaPreferida: fecha,
                latitud: latitud,
                longitud: longitud,
              ),
            );
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _nombreTecnico = nombre;
        _pendientes = pendientes;
        _hoy = hoy;
        _mes = mes;
        _agendaHoy
          ..clear()
          ..addAll(agendaHoy);
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al cargar datos: $e';
        _cargando = false;
      });
    }
  }

  Future<void> _iniciarTrabajo(_TrabajoTecnico trabajo) async {
    try {
      await FirebaseFirestore.instance
          .collection('requests')
          .doc(trabajo.id)
          .update({'estado': 'en_proceso'});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servicio iniciado')),
      );
      await _cargarDatos();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al iniciar servicio: $e')),
      );
    }
  }

  Future<void> _abrirMapa(_TrabajoTecnico trabajo) async {
    String url;
    if (trabajo.latitud != null && trabajo.longitud != null) {
      url =
          'https://www.google.com/maps/search/?api=1&query=${trabajo.latitud},${trabajo.longitud}';
    } else if (trabajo.direccion.isNotEmpty) {
      final query = Uri.encodeComponent(trabajo.direccion);
      url = 'https://www.google.com/maps/search/?api=1&query=$query';
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sin ubicación disponible')),
      );
      return;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el mapa')),
      );
    }
  }

  String _formatearHora(DateTime? fecha) {
    if (fecha == null) return '';
    final time = TimeOfDay.fromDateTime(fecha);
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatTimeOfDay(time, alwaysUse24HourFormat: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            onPressed: () => AuthService.instance.signOut(),
            icon: const Icon(Icons.logout_rounded),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ───────── HEADER Azul ─────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0A5BFF), Color(0xFF1A73E8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¡Buen día, $_nombreTecnico!',
                        style: const TextStyle(
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _MiniStatCard(
                              number: '$_pendientes', label: 'Pendientes'),
                          _MiniStatCard(number: '$_hoy', label: 'Hoy'),
                          _MiniStatCard(number: '$_mes', label: 'Este mes'),
                        ],
                      )
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Estado de carga / error
              if (_cargando)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              // ───────── Agenda de Hoy ─────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Agenda de Hoy',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _fechaCorta(DateTime.now()),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              if (!_cargando && _agendaHoy.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('No tienes servicios pendientes para hoy.'),
                )
              else
                Column(
                  children: _agendaHoy
                      .map(
                        (t) => _AgendaCard(
                          cliente: t.clienteNombre,
                          titulo: t.titulo,
                          hora: _formatearHora(t.fechaPreferida),
                          direccion: t.direccion,
                          estado: t.estado,
                          onIniciar: () => _iniciarTrabajo(t),
                          onLlamar: () {
                            // TODO: implementar llamadas reales cuando tengas el teléfono
                          },
                          onMapa: () => _abrirMapa(t),
                        ),
                      )
                      .toList(),
                ),

              const SizedBox(height: 20),

              // ───────── Acciones Rápidas ─────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Acciones Rápidas',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                  ),
                  children: [
                    _QuickActionBox(
                      icon: Icons.calendar_today_outlined,
                      label: 'Ver solicitudes',
                      color: Colors.blue.shade100,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TecnicoDashboard(),
                          ),
                        );
                      },
                    ),
                    _QuickActionBox(
                      icon: Icons.assignment_outlined,
                      label: 'Nuevo reporte',
                      color: Colors.green.shade100,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NuevoReporteScreen(),
                          ),
                        );
                      },
                    ),
                    _QuickActionBox(
                      icon: Icons.person_outline,
                      label: 'Mis clientes',
                      color: Colors.purple.shade100,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MisClientesScreen(),
                          ),
                        );
                      },
                    ),
                    _QuickActionBox(
                      icon: Icons.history,
                      label: 'Historial',
                      color: Colors.orange.shade100,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HistorialTecnicoScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fechaCorta(DateTime d) {
    // Ej: 26 Oct 2025
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
    final mes = meses[d.month - 1];
    return '${d.day} $mes ${d.year}';
  }
}

// ─────────────────── MODELO LOCAL ───────────────────

class _TrabajoTecnico {
  final String id;
  final String clienteId;
  final String clienteNombre;
  final String titulo;
  final String direccion;
  final String estado;
  final DateTime? fechaPreferida;
  final double? latitud;
  final double? longitud;

  _TrabajoTecnico({
    required this.id,
    required this.clienteId,
    required this.clienteNombre,
    required this.titulo,
    required this.direccion,
    required this.estado,
    required this.fechaPreferida,
    this.latitud,
    this.longitud,
  });
}

// ─────────────────── WIDGETS UI ───────────────────

class _MiniStatCard extends StatelessWidget {
  final String number;
  final String label;

  const _MiniStatCard({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _AgendaCard extends StatelessWidget {
  final String cliente;
  final String titulo;
  final String hora;
  final String direccion;
  final String estado;
  final VoidCallback onIniciar;
  final VoidCallback onLlamar;
  final VoidCallback onMapa;

  const _AgendaCard({
    required this.cliente,
    required this.titulo,
    required this.hora,
    required this.direccion,
    required this.estado,
    required this.onIniciar,
    required this.onLlamar,
    required this.onMapa,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cliente + estado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  cliente,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    estado,
                    style: TextStyle(color: Colors.green.shade800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(titulo, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time, size: 18),
                const SizedBox(width: 6),
                Text(hora),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text(direccion)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onIniciar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A5BFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Iniciar Trabajo'),
                  ),
                ),
                const SizedBox(width: 10),
                _RoundIcon(icon: Icons.phone, onTap: onLlamar),
                const SizedBox(width: 10),
                _RoundIcon(icon: Icons.map_outlined, onTap: onMapa),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon),
      ),
    );
  }
}

class _QuickActionBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionBox({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Colors.black54),
            const SizedBox(height: 10),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─────────────────── PANTALLAS PLACEHOLDER ───────────────────

class NuevoReporteScreen extends StatefulWidget {
  const NuevoReporteScreen({super.key});

  @override
  State<NuevoReporteScreen> createState() => _NuevoReporteScreenState();
}

class _NuevoReporteScreenState extends State<NuevoReporteScreen> {
  final _formKey = GlobalKey<FormState>();

  // Servicios completados del técnico
  bool _cargandoServicios = true;
  String? _errorServicios;
  final List<_ServicioCompletado> _servicios = [];
  _ServicioCompletado? _servicioSeleccionado;

  // Campos del formulario
  final _resumenCtrl = TextEditingController();
  final _problemasCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  bool _huboProblemas = false;
  bool _requiereSeguimiento = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarServiciosCompletados();
  }

  @override
  void dispose() {
    _resumenCtrl.dispose();
    _problemasCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarServiciosCompletados() async {
    setState(() {
      _cargandoServicios = true;
      _errorServicios = null;
      _servicios.clear();
      _servicioSeleccionado = null;
    });

    try {
      final fbUser = AuthService.instance.currentFbUser;
      if (fbUser == null) {
        setState(() {
          _errorServicios = 'No autenticado';
          _cargandoServicios = false;
        });
        return;
      }
      final uidTecnico = fbUser.uid;
      final db = FirebaseFirestore.instance;

      // Traemos todos los servicios COMPLETADOS del técnico
      final qs = await db
          .collection('requests')
          .where('tecnicoAsignadoId', isEqualTo: uidTecnico)
          .where('estado', isEqualTo: 'completada')
          .orderBy('createdAt', descending: true)
          .get();

      final List<_ServicioCompletado> lista = [];

      for (final doc in qs.docs) {
        final data = doc.data();

        final String tipo = (data['tipo'] ?? 'Servicio').toString();
        final String direccion = (data['direccion'] ?? '').toString();
        final String clienteId = (data['clienteId'] ?? '').toString();
        final Timestamp? ts = data['fechaPreferida'] as Timestamp?;
        final DateTime? fechaServicio = ts?.toDate();

        lista.add(
          _ServicioCompletado(
            id: doc.id,
            tipo: tipo,
            direccion: direccion,
            clienteId: clienteId,
            fechaServicio: fechaServicio,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _servicios.addAll(lista);
        _cargandoServicios = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorServicios = 'Error al cargar servicios: $e';
        _cargandoServicios = false;
      });
    }
  }

  String _fechaCorta(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  Future<void> _guardarReporte() async {
    if (_servicioSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un servicio para reportar.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_huboProblemas && _problemasCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Describe los problemas encontrados, por favor.')),
      );
      return;
    }

    final fbUser = AuthService.instance.currentFbUser;
    if (fbUser == null) return;

    final servicio = _servicioSeleccionado!;

    setState(() => _guardando = true);
    try {
      final db = FirebaseFirestore.instance;

      await db.collection('serviceReports').add({
        'requestId': servicio.id,
        'tecnicoId': fbUser.uid,
        'clienteId': servicio.clienteId,
        'tipoServicio': servicio.tipo,
        'direccion': servicio.direccion,
        'fechaServicio': servicio.fechaServicio != null
            ? Timestamp.fromDate(servicio.fechaServicio!)
            : null,
        'resumenTrabajo': _resumenCtrl.text.trim(),
        'huboProblemas': _huboProblemas,
        'detallesProblemas':
            _huboProblemas ? _problemasCtrl.text.trim() : null,
        'requiereSeguimiento': _requiereSeguimiento,
        'observaciones':
            _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
        'estadoRevision': 'pendiente', // para el administrador
        'createdAt': Timestamp.now(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reporte enviado al administrador')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar reporte: $e')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo reporte'),
      ),
      body: RefreshIndicator(
        onRefresh: _cargarServiciosCompletados,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Servicio a reportar',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              if (_cargandoServicios)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_errorServicios != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _errorServicios!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              else if (_servicios.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16.0),
                  child: Text('No tienes servicios completados para reportar.'),
                )
              else
              DropdownButtonFormField<_ServicioCompletado>(
                initialValue: _servicioSeleccionado,
                isExpanded: true, // para que use todo el ancho
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Selecciona un servicio',
                ),
                items: _servicios.map((s) {
                  final fecha = _fechaCorta(s.fechaServicio);

                  // Texto compacto en una sola línea
                  final texto = [
                    s.tipo,
                    if (fecha.isNotEmpty) fecha,
                    if (s.direccion.isNotEmpty) s.direccion,
                  ].join(' • ');

                  return DropdownMenuItem<_ServicioCompletado>(
                    value: s,
                    child: Text(
                      texto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _servicioSeleccionado = val);
                },
                validator: (val) {
                  if (val == null) {
                    return 'Selecciona un servicio';
                  }
                  return null;
                },
              ),

            const SizedBox(height: 24),

              Text(
                'Detalles del reporte',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _resumenCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Resumen del trabajo realizado',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 10) {
                          return 'Describe brevemente el trabajo (al menos 10 caracteres).';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    SwitchListTile(
                      title: const Text('¿Hubo problemas durante el servicio?'),
                      value: _huboProblemas,
                      onChanged: (v) {
                        setState(() => _huboProblemas = v);
                      },
                    ),

                    if (_huboProblemas)
                      Column(
                        children: [
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _problemasCtrl,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Describe los problemas o incidentes',
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),

                    SwitchListTile(
                      title: const Text('¿Requiere seguimiento / próxima visita?'),
                      value: _requiereSeguimiento,
                      onChanged: (v) {
                        setState(() => _requiereSeguimiento = v);
                      },
                    ),

                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _obsCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Comentarios adicionales (opcional)',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _guardando ? null : _guardarReporte,
                  icon: _guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text('Enviar reporte'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServicioCompletado {
  final String id;
  final String tipo;
  final String direccion;
  final String clienteId;
  final DateTime? fechaServicio;

  _ServicioCompletado({
    required this.id,
    required this.tipo,
    required this.direccion,
    required this.clienteId,
    required this.fechaServicio,
  });
}

class MisClientesScreen extends StatefulWidget {
  const MisClientesScreen({super.key});

  @override
  State<MisClientesScreen> createState() => _MisClientesScreenState();
}

class _MisClientesScreenState extends State<MisClientesScreen> {
  bool _cargando = true;
  String? _error;

  final List<_ClienteResumen> _clientes = [];

  @override
  void initState() {
    super.initState();
    _cargarClientes();
  }

  Future<void> _cargarClientes() async {
    setState(() {
      _cargando = true;
      _error = null;
      _clientes.clear();
    });

    try {
      final fbUser = AuthService.instance.currentFbUser;
      if (fbUser == null) {
        setState(() {
          _error = 'No autenticado';
          _cargando = false;
        });
        return;
      }

      final uidTecnico = fbUser.uid;
      final db = FirebaseFirestore.instance;

      // Todas las solicitudes COMPLETADAS de este técnico
      final qs = await db
          .collection('requests')
          .where('tecnicoAsignadoId', isEqualTo: uidTecnico)
          .where('estado', isEqualTo: 'completada')
          .get();

      // Conteo de servicios por cliente
      final Map<String, int> conteo = {};
      final Map<String, DateTime?> ultimaFecha = {};

      for (final doc in qs.docs) {
        final data = doc.data();
        final String clienteId = (data['clienteId'] ?? '').toString();
        if (clienteId.isEmpty) continue;

        conteo[clienteId] = (conteo[clienteId] ?? 0) + 1;

        final ts = data['fechaPreferida'] as Timestamp?;
        final dt = ts?.toDate();
        final actual = ultimaFecha[clienteId];
        if (actual == null || (dt != null && dt.isAfter(actual))) {
          ultimaFecha[clienteId] = dt;
        }
      }

      // Cargar nombres desde /users/{clienteId}
      final List<_ClienteResumen> lista = [];
      for (final entry in conteo.entries) {
        final clienteId = entry.key;
        final count = entry.value;
        final fecha = ultimaFecha[clienteId];

        final userSnap =
            await db.collection('users').doc(clienteId).get(); // puede no existir
        final userData = userSnap.data();
        final nombre = (userData?['nombre'] ?? clienteId).toString();

        lista.add(
          _ClienteResumen(
            id: clienteId,
            nombre: nombre,
            servicios: count,
            ultimaFecha: fecha,
          ),
        );
      }

      // Ordenar por última fecha de servicio (más recientes primero)
      lista.sort((a, b) {
        final fa = a.ultimaFecha ?? DateTime.fromMillisecondsSinceEpoch(0);
        final fb = b.ultimaFecha ?? DateTime.fromMillisecondsSinceEpoch(0);
        return fb.compareTo(fa);
      });

      if (!mounted) return;
      setState(() {
        _clientes
          ..clear()
          ..addAll(lista);
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al cargar clientes: $e';
        _cargando = false;
      });
    }
  }

  String _formatearFecha(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis clientes')),
      body: RefreshIndicator(
        onRefresh: _cargarClientes,
        child: _cargando
            ? ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              )
            : _error != null
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  )
                : _clientes.isEmpty
                    ? ListView(
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Aún no tienes clientes registrados.'),
                          ),
                        ],
                      )
                    : ListView.builder(
                        itemCount: _clientes.length,
                        itemBuilder: (context, index) {
                          final c = _clientes[index];
                          return ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.person_outline),
                            ),
                            title: Text(c.nombre),
                            subtitle: Text(
                              'Servicios realizados: ${c.servicios}'
                              '${c.ultimaFecha != null ? '\nÚltimo servicio: ${_formatearFecha(c.ultimaFecha)}' : ''}',
                            ),
                            isThreeLine: c.ultimaFecha != null,
                          );
                        },
                      ),
      ),
    );
  }
}

class _ClienteResumen {
  final String id;
  final String nombre;
  final int servicios;
  final DateTime? ultimaFecha;

  _ClienteResumen({
    required this.id,
    required this.nombre,
    required this.servicios,
    required this.ultimaFecha,
  });
}

class HistorialTecnicoScreen extends StatefulWidget {
  const HistorialTecnicoScreen({super.key});

  @override
  State<HistorialTecnicoScreen> createState() => _HistorialTecnicoScreenState();
}

class _HistorialTecnicoScreenState extends State<HistorialTecnicoScreen> {
  bool _cargando = true;
  String? _error;

  final List<_ServicioHistorial> _servicios = [];
  final Map<String, String> _nombresClientes = {}; // clienteId -> nombre

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    setState(() {
      _cargando = true;
      _error = null;
      _servicios.clear();
      _nombresClientes.clear();
    });

    try {
      final fbUser = AuthService.instance.currentFbUser;
      if (fbUser == null) {
        setState(() {
          _error = 'No autenticado';
          _cargando = false;
        });
        return;
      }

      final uidTecnico = fbUser.uid;
      final db = FirebaseFirestore.instance;

      // 1) Traer todas las requests completadas de este técnico
      final qs = await db
          .collection('requests')
          .where('tecnicoAsignadoId', isEqualTo: uidTecnico)
          .where('estado', isEqualTo: 'completada')
          .orderBy('createdAt', descending: true)
          .get();

      final List<_ServicioHistorial> lista = [];
      final Set<String> clientesIds = <String>{};

      for (final doc in qs.docs) {
        final data = doc.data();
        final String tipo = (data['tipo'] ?? 'Servicio').toString();
        final String direccion = (data['direccion'] ?? '').toString();
        final String clienteId = (data['clienteId'] ?? '').toString();
        final ts = data['fechaPreferida'] as Timestamp?;
        final DateTime? dt = ts?.toDate();

        if (clienteId.isNotEmpty) {
          clientesIds.add(clienteId);
        }

        lista.add(
          _ServicioHistorial(
            id: doc.id,
            tipo: tipo,
            direccion: direccion,
            clienteId: clienteId,
            fecha: dt,
          ),
        );
      }

      // 2) Cargar nombres de todos esos clientes de una vez
      for (final clienteId in clientesIds) {
        final snap = await db.collection('users').doc(clienteId).get();
        final data = snap.data();

        // 👇 Cambia 'nombre' por el nombre real del campo (name, displayName, etc.)
        final nombre = (data?['nombre'] ?? clienteId).toString();

        _nombresClientes[clienteId] = nombre;
      }

      if (!mounted) return;
      setState(() {
        _servicios
          ..clear()
          ..addAll(lista);
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al cargar historial: $e';
        _cargando = false;
      });
    }
  }

  String _formatearFechaHora(DateTime? d) {
    if (d == null) return '';
    final date =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final timeOfDay = TimeOfDay.fromDateTime(d);
    final localizations = MaterialLocalizations.of(context);
    final hora = localizations.formatTimeOfDay(
      timeOfDay,
      alwaysUse24HourFormat: false,
    );
    return '$date · $hora';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de servicios')),
      body: RefreshIndicator(
        onRefresh: _cargarHistorial,
        child: _cargando
            ? ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              )
            : _error != null
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  )
                : _servicios.isEmpty
                    ? ListView(
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(16.0),
                            child:
                                Text('Aún no tienes servicios completados.'),
                          ),
                        ],
                      )
                    : ListView.builder(
                        itemCount: _servicios.length,
                        itemBuilder: (context, index) {
                          final s = _servicios[index];
                          final nombreCliente =
                              _nombresClientes[s.clienteId] ?? s.clienteId;

                          return ListTile(
                            leading: const Icon(
                              Icons.check_circle_outline,
                              color: Colors.green,
                            ),
                            title: Text(s.tipo),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (s.clienteId.isNotEmpty)
                                  Text('Cliente: $nombreCliente'),
                                if (s.fecha != null)
                                  Text(_formatearFechaHora(s.fecha)),
                                if (s.direccion.isNotEmpty)
                                  Text('Dirección: ${s.direccion}'),
                              ],
                            ),
                            isThreeLine: true,
                          );
                        },
                      ),
      ),
    );
  }
}

class _ServicioHistorial {
  final String id;
  final String tipo;
  final String direccion;
  final String clienteId;
  final DateTime? fecha;

  _ServicioHistorial({
    required this.id,
    required this.tipo,
    required this.direccion,
    required this.clienteId,
    required this.fecha,
  });
}