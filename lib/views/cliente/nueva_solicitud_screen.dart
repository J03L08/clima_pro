import 'package:flutter/material.dart';
import 'package:clima_pro/services/auth_service.dart';
import 'package:clima_pro/services/requests_service.dart';

import 'package:clima_pro/views/home/home_cliente.dart';
import 'package:clima_pro/views/cliente/mis_solicitudes_screen.dart';
import 'package:clima_pro/views/home/avisos_screen.dart';
import 'package:clima_pro/views/home/perfil_screen.dart';
import 'package:clima_pro/widgets/cliente_bottom_nav.dart';

// 👇 NUEVO: usamos flutter_map + latlong2
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;

class NuevaSolicitudScreen extends StatefulWidget {
  const NuevaSolicitudScreen({super.key});

  static const routeName = '/nueva-solicitud';

  @override
  State<NuevaSolicitudScreen> createState() => _NuevaSolicitudScreenState();
}

class _NuevaSolicitudScreenState extends State<NuevaSolicitudScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _tipo;
  final _direccion = TextEditingController();
  final _descripcion = TextEditingController();

  DateTime? _fechaPreferida;
  TimeOfDay? _horaPreferida;

  bool _saving = false;

  // ⭐ Campos para guardar coordenadas seleccionadas
  double? _latitud;
  double? _longitud;

  static const Set<String> _tiposValidos = {
    'instalacion',
    'reparacion',
    'mantenimiento',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['tipo'] is String) {
      final t = (args['tipo'] as String).toLowerCase();
      if (_tiposValidos.contains(t)) {
        _tipo ??= t;
      }
    }
  }

  @override
  void dispose() {
    _direccion.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 180)),
      initialDate: _fechaPreferida ?? now,
    );
    if (picked != null) setState(() => _fechaPreferida = picked);
  }

  Future<void> _pickTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _horaPreferida ?? TimeOfDay.now());
    if (picked != null) setState(() => _horaPreferida = picked);
  }

  String _formatDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final mon = d.month.toString().padLeft(2, '0');
    return '$day/$mon/${d.year}';
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final suf = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $suf';
  }

  DateTime? _combineDateTime(DateTime? d, TimeOfDay? t) {
    if (d == null) return null;
    if (t == null) return DateTime(d.year, d.month, d.day);
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  // ⭐ Abrir pantalla de mapa para seleccionar ubicación (con flutter_map)
  Future<void> _abrirMapa() async {
    // Ubicación inicial aproximada (por ejemplo, CDMX)
    const latlng.LatLng ubicacionInicial = latlng.LatLng(19.432608, -99.133209);

    final resultado = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SeleccionarUbicacionScreen(
          ubicacionInicial: ubicacionInicial,
          latInicial: _latitud,
          lngInicial: _longitud,
        ),
      ),
    );

    if (resultado != null) {
      setState(() {
        _latitud = resultado['lat'] as double;
        _longitud = resultado['lng'] as double;
        final direccion = resultado['direccion'] as String?;
        if (direccion != null && direccion.isNotEmpty) {
          _direccion.text = direccion;
        }
      });
    }
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    FocusScope.of(context).unfocus();

    final uid = AuthService.instance.currentFbUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No se encontró sesión de usuario')));
      return;
    }

    final fechaPreferida = _combineDateTime(_fechaPreferida, _horaPreferida);

    setState(() => _saving = true);
    try {
      await RequestsService.instance.createSolicitud(
        clienteId: uid,
        tipo: _tipo!,
        descripcion: _descripcion.text.trim().isEmpty ? '' : _descripcion.text.trim(),
        direccion: _direccion.text.trim(),
        latitud: _latitud,
        longitud: _longitud,
        fechaPreferida: fechaPreferida,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Solicitud enviada')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String label, {String? hint, Widget? suffixIcon, bool align = false}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: align,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Colors.blue),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solicitar Servicio',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Completa los datos para tu solicitud',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 16),

                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _tipo,
                            decoration: _dec(
                              'Tipo de Servicio',
                              hint: 'Selecciona un servicio',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'instalacion',
                                child: Text('Instalación'),
                              ),
                              DropdownMenuItem(
                                value: 'mantenimiento',
                                child: Text('Mantenimiento'),
                              ),
                              DropdownMenuItem(
                                value: 'reparacion',
                                child: Text('Reparación'),
                              ),
                            ],
                            onChanged: (v) => setState(() => _tipo = v),
                            validator: (v) =>
                                (v == null || v.isEmpty)
                                    ? 'Selecciona un tipo de servicio'
                                    : null,
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _direccion,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.next,
                            decoration: _dec(
                              'Dirección',
                              hint: 'Calle, número, colonia',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.map_outlined),
                                onPressed: _abrirMapa,
                              ),
                            ),
                            validator: (v) {
                            final hasText = v != null && v.trim().isNotEmpty;
                            final hasCoords = _latitud != null && _longitud != null;

                            if (!hasText && !hasCoords) {
                              return 'Ingresa la dirección o selecciona una ubicación en el mapa';
                            }
                            return null;
                          },
                          ),
                          const SizedBox(height: 6),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _abrirMapa,
                              icon: const Icon(Icons.location_on_outlined),
                              label: Text(
                                _latitud != null && _longitud != null
                                    ? 'Ubicación seleccionada en el mapa'
                                    : 'Seleccionar ubicación en el mapa',
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  readOnly: true,
                                  decoration: _dec(
                                    'Fecha Preferida',
                                    hint: 'dd/mm/aaaa',
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.calendar_today),
                                      onPressed: _pickDate,
                                    ),
                                  ),
                                  onTap: _pickDate,
                                  controller: TextEditingController(
                                    text: _fechaPreferida == null
                                        ? ''
                                        : _formatDate(_fechaPreferida!),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  readOnly: true,
                                  decoration: _dec(
                                    'Hora Preferida',
                                    hint: '--:--  ----',
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.access_time),
                                      onPressed: _pickTime,
                                    ),
                                  ),
                                  onTap: _pickTime,
                                  controller: TextEditingController(
                                    text: _horaPreferida == null
                                        ? ''
                                        : _formatTime(_horaPreferida!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _descripcion,
                            maxLines: 4,
                            textInputAction: TextInputAction.newline,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: _dec(
                              'Descripción del Problema (opcional)',
                              hint: 'Describe los detalles de tu solicitud...',
                              align: true,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              return v.trim().length < 10
                                  ? 'Si agregas descripción, usa al menos 10 caracteres'
                                  : null;
                            },
                          ),
                          const SizedBox(height: 12),

                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: cs.primary.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline, color: cs.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Un técnico se pondrá en contacto contigo para confirmar la fecha y hora de tu servicio.',
                                    style: TextStyle(color: Colors.grey[800]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _saving ? null : _submit,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _saving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Enviar Solicitud'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      bottomNavigationBar: ClienteBottomNav(
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeCliente()),
            );
            return;
          }
          if (index == 1) {
            Navigator.pushReplacementNamed(
              context,
              MisSolicitudesScreen.routeName,
            );
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

class SeleccionarUbicacionScreen extends StatefulWidget {
  final latlng.LatLng ubicacionInicial;
  final double? latInicial;
  final double? lngInicial;

  const SeleccionarUbicacionScreen({
    super.key,
    required this.ubicacionInicial,
    this.latInicial,
    this.lngInicial,
  });

  @override
  State<SeleccionarUbicacionScreen> createState() => _SeleccionarUbicacionScreenState();
}

class _SeleccionarUbicacionScreenState extends State<SeleccionarUbicacionScreen> {
  final MapController _mapController = MapController();
  latlng.LatLng? _marcador;

  @override
  void initState() {
    super.initState();
    if (widget.latInicial != null && widget.lngInicial != null) {
      _marcador = latlng.LatLng(widget.latInicial!, widget.lngInicial!);
    }
  }

  Future<void> _confirmarUbicacion() async {
  if (_marcador == null) return;

  final lat = _marcador!.latitude;
  final lng = _marcador!.longitude;

  final direccionTexto = 'Ubicación en mapa ($lat, $lng)';

  Navigator.of(context).pop({
    'lat': lat,
    'lng': lng,
    'direccion': direccionTexto,
  });
}

  @override
  Widget build(BuildContext context) {
    final latlng.LatLng initial = _marcador ?? widget.ubicacionInicial;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar ubicación'),
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initial,
                initialZoom: 15,
                onTap: (tapPosition, point) {
                  setState(() {
                    _marcador = point;
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.climapro.app', // pon tu packageId
                ),
                MarkerLayer(
                  markers: [
                    if (_marcador != null)
                      Marker(
                        point: _marcador!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          size: 34,
                          color: Colors.red,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _marcador == null ? null : _confirmarUbicacion,
                child: const Text('Confirmar ubicación'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}