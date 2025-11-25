import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:clima_pro/services/auth_service.dart';

import 'admin_report_detail_screen.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  bool _cargando = true;
  String? _error;

  final List<_ServiceReport> _reportes = [];
  final Map<String, String> _nombresUsuarios = {}; // uid -> nombre

  String _filtroEstado = 'todos'; // todos | pendiente | revisado | cerrado

  @override
  void initState() {
    super.initState();
    _cargarReportes();
  }

  Future<void> _cargarReportes() async {
    setState(() {
      _cargando = true;
      _error = null;
      _reportes.clear();
      _nombresUsuarios.clear();
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

      // (opcional) aquí podrías verificar que el rol sea admin antes de seguir

      final db = FirebaseFirestore.instance;

      Query query = db.collection('serviceReports');

      if (_filtroEstado != 'todos') {
        query = query.where('estadoRevision', isEqualTo: _filtroEstado);
      }

      query = query.orderBy('createdAt', descending: true);

      final qs = await query.get();

      final List<_ServiceReport> lista = [];
      final Set<String> uids = {};

      for (final doc in qs.docs) {
        final Map<String, dynamic> data =
          (doc.data() as Map<String, dynamic>?) ?? {};

        final String tecnicoId = (data['tecnicoId'] ?? '').toString();
        final String clienteId = (data['clienteId'] ?? '').toString();
        final String requestId = (data['requestId'] ?? '').toString();
        final String tipoServicio =
            (data['tipoServicio'] ?? 'Servicio').toString();
        final String direccion = (data['direccion'] ?? '').toString();
        final String resumenTrabajo =
            (data['resumenTrabajo'] ?? '').toString();
        final bool huboProblemas = (data['huboProblemas'] == true);
        final String? detallesProblemas =
            (data['detallesProblemas'] as String?);
        final bool requiereSeguimiento =
            (data['requiereSeguimiento'] == true);
        final String? observaciones = (data['observaciones'] as String?);
        final String estadoRevision =
            (data['estadoRevision'] ?? 'pendiente').toString();
        final Timestamp? tsFechaServicio =
            data['fechaServicio'] as Timestamp?;
        final Timestamp? tsCreatedAt = data['createdAt'] as Timestamp?;
        final String? comentarioAdmin =
            (data['comentarioAdmin'] as String?);

        final DateTime? fechaServicio = tsFechaServicio?.toDate();
        final DateTime? createdAt = tsCreatedAt?.toDate();

        if (tecnicoId.isNotEmpty) uids.add(tecnicoId);
        if (clienteId.isNotEmpty) uids.add(clienteId);

        lista.add(
          _ServiceReport(
            id: doc.id,
            requestId: requestId,
            tecnicoId: tecnicoId,
            clienteId: clienteId,
            tipoServicio: tipoServicio,
            direccion: direccion,
            fechaServicio: fechaServicio,
            resumenTrabajo: resumenTrabajo,
            huboProblemas: huboProblemas,
            detallesProblemas: detallesProblemas,
            requiereSeguimiento: requiereSeguimiento,
            observaciones: observaciones,
            estadoRevision: estadoRevision,
            createdAt: createdAt,
            comentarioAdmin: comentarioAdmin,
          ),
        );
      }

      // Cargar nombres (clientes/técnicos) desde /users
      for (final uid in uids) {
        try {
          final snap = await db.collection('users').doc(uid).get();
          final data = snap.data();
          final nombre = (data?['nombre'] ?? uid).toString();
          _nombresUsuarios[uid] = nombre;
        } catch (_) {
          _nombresUsuarios[uid] = uid;
        }
      }

      if (!mounted) return;
      setState(() {
        _reportes.addAll(lista);
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al cargar reportes: $e';
        _cargando = false;
      });
    }
  }

  String _nombreUsuario(String uid) {
    if (uid.isEmpty) return 'N/D';
    return _nombresUsuarios[uid] ?? uid;
  }

  String _fechaCorta(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return Colors.orange.shade100;
      case 'revisado':
        return Colors.green.shade100;
      case 'cerrado':
        return Colors.blue.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _colorEstadoTexto(String estado) {
    switch (estado) {
      case 'pendiente':
        return Colors.orange.shade800;
      case 'revisado':
        return Colors.green.shade800;
      case 'cerrado':
        return Colors.blue.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de servicios'),
      ),
      body: RefreshIndicator(
        onRefresh: _cargarReportes,
        child: Column(
          children: [
            // Filtro por estado
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const Text('Estado: '),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _filtroEstado,
                    items: const [
                      DropdownMenuItem(
                        value: 'todos',
                        child: Text('Todos'),
                      ),
                      DropdownMenuItem(
                        value: 'pendiente',
                        child: Text('Pendientes'),
                      ),
                      DropdownMenuItem(
                        value: 'revisado',
                        child: Text('Revisados'),
                      ),
                      DropdownMenuItem(
                        value: 'cerrado',
                        child: Text('Cerrados'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() => _filtroEstado = val);
                      _cargarReportes();
                    },
                  ),
                ],
              ),
            ),

            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
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
                      : _reportes.isEmpty
                          ? ListView(
                              children: const [
                                Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('No hay reportes.'),
                                ),
                              ],
                            )
                          : ListView.builder(
                              itemCount: _reportes.length,
                              itemBuilder: (context, index) {
                                final r = _reportes[index];
                                final fecha = _fechaCorta(r.fechaServicio);
                                final nombreTecnico =
                                    _nombreUsuario(r.tecnicoId);
                                final nombreCliente =
                                    _nombreUsuario(r.clienteId);

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: ListTile(
                                    onTap: () async {
                                      final changed =
                                          await Navigator.of(context).push<bool>(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              AdminReportDetailScreen(
                                            reportId: r.id,
                                          ),
                                        ),
                                      );
                                      if (changed == true) {
                                        _cargarReportes();
                                      }
                                    },
                                    title: Text(
                                      r.tipoServicio,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (fecha.isNotEmpty) Text('Fecha: $fecha'),
                                        Text('Técnico: $nombreTecnico'),
                                        Text('Cliente: $nombreCliente'),
                                        Text(
                                          r.resumenTrabajo,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _colorEstado(r.estadoRevision),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        r.estadoRevision,
                                        style: TextStyle(
                                          color: _colorEstadoTexto(
                                              r.estadoRevision),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceReport {
  final String id;
  final String requestId;
  final String tecnicoId;
  final String clienteId;
  final String tipoServicio;
  final String direccion;
  final DateTime? fechaServicio;
  final String resumenTrabajo;
  final bool huboProblemas;
  final String? detallesProblemas;
  final bool requiereSeguimiento;
  final String? observaciones;
  final String estadoRevision;
  final DateTime? createdAt;
  final String? comentarioAdmin;

  _ServiceReport({
    required this.id,
    required this.requestId,
    required this.tecnicoId,
    required this.clienteId,
    required this.tipoServicio,
    required this.direccion,
    required this.fechaServicio,
    required this.resumenTrabajo,
    required this.huboProblemas,
    required this.detallesProblemas,
    required this.requiereSeguimiento,
    required this.observaciones,
    required this.estadoRevision,
    required this.createdAt,
    required this.comentarioAdmin,
  });
}