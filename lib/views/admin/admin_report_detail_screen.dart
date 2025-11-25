import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminReportDetailScreen extends StatefulWidget {
  final String reportId;

  const AdminReportDetailScreen({
    super.key,
    required this.reportId,
  });

  @override
  State<AdminReportDetailScreen> createState() =>
      _AdminReportDetailScreenState();
}

class _AdminReportDetailScreenState extends State<AdminReportDetailScreen> {
  bool _cargando = true;
  String? _error;

  String _tipoServicio = '';
  String _direccion = '';
  String _tecnicoId = '';
  String _clienteId = '';
  DateTime? _fechaServicio;
  String _resumenTrabajo = '';
  bool _huboProblemas = false;
  String? _detallesProblemas;
  bool _requiereSeguimiento = false;
  String? _observaciones;
  String _estadoRevision = 'pendiente';
  DateTime? _createdAt;
  String? _comentarioAdmin;

  final _comentarioCtrl = TextEditingController();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarDetalle();
  }

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDetalle() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final snap = await FirebaseFirestore.instance
          .collection('serviceReports')
          .doc(widget.reportId)
          .get();

      if (!snap.exists) {
        if (!mounted) return;
        setState(() {
          _error = 'Reporte no encontrado';
          _cargando = false;
        });
        return;
      }

      final data = snap.data()!;
      final tsFecha = data['fechaServicio'] as Timestamp?;
      final tsCreated = data['createdAt'] as Timestamp?;

      setState(() {
        _tipoServicio = (data['tipoServicio'] ?? '').toString();
        _direccion = (data['direccion'] ?? '').toString();
        _tecnicoId = (data['tecnicoId'] ?? '').toString();
        _clienteId = (data['clienteId'] ?? '').toString();
        _fechaServicio = tsFecha?.toDate();
        _resumenTrabajo = (data['resumenTrabajo'] ?? '').toString();
        _huboProblemas = data['huboProblemas'] == true;
        _detallesProblemas = data['detallesProblemas'] as String?;
        _requiereSeguimiento = data['requiereSeguimiento'] == true;
        _observaciones = data['observaciones'] as String?;
        _estadoRevision =
            (data['estadoRevision'] ?? 'pendiente').toString();
        _createdAt = tsCreated?.toDate();
        _comentarioAdmin = data['comentarioAdmin'] as String?;
        _comentarioCtrl.text = _comentarioAdmin ?? '';
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al cargar reporte: $e';
        _cargando = false;
      });
    }
  }

  String _fechaHora(DateTime? d) {
    if (d == null) return '';
    final date =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final tod = TimeOfDay.fromDateTime(d);
    final l = MaterialLocalizations.of(context);
    final h = l.formatTimeOfDay(tod, alwaysUse24HourFormat: false);
    return '$date · $h';
  }

  Future<void> _guardarCambios() async {
    setState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance
          .collection('serviceReports')
          .doc(widget.reportId)
          .update({
        'estadoRevision': _estadoRevision,
        'comentarioAdmin':
            _comentarioCtrl.text.trim().isEmpty ? null : _comentarioCtrl.text.trim(),
        'updatedAt': Timestamp.now(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reporte actualizado')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
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
        title: const Text('Detalle del reporte'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tipoServicio,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      if (_fechaServicio != null)
                        Text('Fecha servicio: ${_fechaHora(_fechaServicio)}'),
                      if (_createdAt != null)
                        Text(
                            'Reporte creado: ${_fechaHora(_createdAt)}',
                            style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                      if (_direccion.isNotEmpty)
                        Text('Dirección: $_direccion'),
                      const SizedBox(height: 12),
                      Text('Técnico: $_tecnicoId'),
                      Text('Cliente: $_clienteId'),
                      const Divider(height: 32),

                      Text(
                        'Resumen del trabajo',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(_resumenTrabajo),
                      const SizedBox(height: 16),

                      if (_huboProblemas) ...[
                        Text(
                          'Problemas durante el servicio',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(_detallesProblemas ?? 'Sin detalles'),
                        const SizedBox(height: 16),
                      ],

                      Text(
                        'Requiere seguimiento',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(_requiereSeguimiento ? 'Sí' : 'No'),
                      const SizedBox(height: 16),

                      if (_observaciones != null &&
                          _observaciones!.trim().isNotEmpty) ...[
                        Text(
                          'Comentarios adicionales del técnico',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(_observaciones!),
                        const SizedBox(height: 16),
                      ],

                      const Divider(height: 32),

                      Text(
                        'Revisión del administrador',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          const Text('Estado: '),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: _estadoRevision,
                            items: const [
                              DropdownMenuItem(
                                  value: 'pendiente', child: Text('Pendiente')),
                              DropdownMenuItem(
                                  value: 'revisado', child: Text('Revisado')),
                              DropdownMenuItem(
                                  value: 'cerrado', child: Text('Cerrado')),
                            ],
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() => _estadoRevision = val);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _comentarioCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Comentario del administrador (opcional)',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _guardando ? null : _guardarCambios,
                          child: _guardando
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Text('Guardar cambios'),
                        ),
                      )
                    ],
                  ),
                ),
    );
  }
}