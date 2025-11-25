import 'package:clima_pro/services/auth_service.dart';
import 'package:flutter/material.dart';

class RoleSelectorScreen extends StatefulWidget {
  const RoleSelectorScreen({super.key});
  @override
  State<RoleSelectorScreen> createState() => _RoleSelectorScreenState();
}

class _RoleSelectorScreenState extends State<RoleSelectorScreen> {
  String? _role;
  bool _saving = false;

  Future<void> _save() async {
    if (_role == null) return;
    setState(() => _saving = true);
    await AuthService.instance.setRole(_role!);
    if (mounted) setState(() => _saving = false);
  }

  Widget _tile(String value, String title, String subtitle) => RadioListTile<String>(
        value: value, groupValue: _role, title: Text(title), subtitle: Text(subtitle),
        onChanged: (v) => setState(() => _role = v),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: [
        TextButton(onPressed: () => AuthService.instance.signOut(), child: const Text('Salir'))
      ], title: const Text('Selecciona tu rol')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tile('cliente','Cliente','Solicita instalaciones y mantenimientos.'),
          _tile('tecnico','Técnico','Gestiona trabajos y llena reportes.'),
          _tile('admin','Administrador','Gestiona tarifas, servicios y zonas.'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}