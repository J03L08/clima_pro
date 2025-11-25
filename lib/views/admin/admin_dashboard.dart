import 'package:clima_pro/models/solicitud.dart';
import 'package:clima_pro/services/requests_service.dart';
import 'package:clima_pro/services/users_service.dart';
import 'package:flutter/material.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin – Solicitudes')),
      body: StreamBuilder<List<Solicitud>>(
        stream: RequestsService.instance.todasDesc(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data ?? [];
          if (data.isEmpty) return const Center(child: Text('Sin solicitudes.'));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: data.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final s = data[i];
              return ListTile(
                title: Text('${_title(s.tipo)} · ${s.estado}'),
                subtitle: Text('${s.descripcion}\n${s.direccion}',
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                isThreeLine: true,
                trailing: (s.estado == 'pendiente')
                    ? OutlinedButton(
                        onPressed: () => _abrirAsignar(context, s.id),
                        child: const Text('Asignar'),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  String _title(String t) => switch (t) {
        'instalacion' => 'Instalación',
        'mantenimiento' => 'Mantenimiento',
        'reparacion' => 'Reparación',
        _ => t,
      };

  void _abrirAsignar(BuildContext context, String requestId) {
    showDialog(
      context: context,
      builder: (_) => _AsignarDialog(requestId: requestId),
    );
  }
}

class _AsignarDialog extends StatefulWidget {
  const _AsignarDialog({required this.requestId});
  final String requestId;

  @override
  State<_AsignarDialog> createState() => _AsignarDialogState();
}

class _AsignarDialogState extends State<_AsignarDialog> {
  String? _tecnicoId;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Asignar técnico'),
      content: SizedBox(
        width: 420,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: UsersService.instance.tecnicos(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final tecnicos = snap.data!;
            if (tecnicos.isEmpty) return const Text('No hay técnicos registrados.');
            return DropdownButtonFormField<String>(
              initialValue: _tecnicoId,
              items: [
                for (final t in tecnicos)
                  DropdownMenuItem(value: t['uid'] as String, child: Text(t['email'] ?? t['uid'])),
              ],
              onChanged: (v) => setState(() => _tecnicoId = v),
              decoration: const InputDecoration(labelText: 'Técnico', border: OutlineInputBorder()),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: (_tecnicoId == null || _saving)
              ? null
              : () async {
                  setState(() => _saving = true);
                  await RequestsService.instance.adminAsignar(widget.requestId, _tecnicoId!);
                  if (context.mounted) Navigator.pop(context);
                },
          child: _saving
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Asignar'),
        ),
      ],
    );
  }
}