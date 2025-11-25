import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:clima_pro/services/auth_service.dart';
import 'package:clima_pro/views/auth/login_screen.dart';
import 'package:clima_pro/views/home/home_cliente.dart';
import 'package:clima_pro/views/cliente/mis_solicitudes_screen.dart';
import 'package:clima_pro/views/home/avisos_screen.dart';
import 'package:clima_pro/widgets/cliente_bottom_nav.dart';

import 'edit_perfil_screen.dart';
import 'ayuda_soporte_screen.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});
  static const routeName = '/perfil';

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  int unreadNotifications = 3;

  String? _displayName;
  String? _photoUrl;

  // Nombre que viene de Firestore (users/{uid}.nombre)
  String? _nombrePerfil;
  bool _cargandoNombre = true;

  @override
  void initState() {
    super.initState();
    final user = AuthService.instance.currentFbUser;
    _displayName = user?.displayName;
    _photoUrl = user?.photoURL;
    _cargarNombreFirestore();
  }

  Future<void> _cargarNombreFirestore() async {
    final user = AuthService.instance.currentFbUser;
    if (user == null) {
      setState(() => _cargandoNombre = false);
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snap.data();
      setState(() {
        _nombrePerfil = (data?['nombre'] as String?)?.trim();
        _cargandoNombre = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargandoNombre = false);
    }
  }

  Future<void> _logout() async {
    try {
      await AuthService.instance.signOut();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _openEditProfile() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const EditPerfilScreen()),
    );

    // Si regresamos con "true", recargamos datos del usuario
    if (changed == true) {
      final user = AuthService.instance.currentFbUser;
      setState(() {
        _displayName = user?.displayName;
        _photoUrl = user?.photoURL;
      });
      await _cargarNombreFirestore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentFbUser;
    final email = user?.email ?? 'usuario@email.com';
    final initial = (email.isNotEmpty ? email[0] : 'U').toUpperCase();

    // Prioridad: nombre en Firestore -> displayName -> texto por defecto
    final name = (_nombrePerfil != null && _nombrePerfil!.isNotEmpty)
        ? _nombrePerfil!
        : (_displayName?.isNotEmpty == true ? _displayName! : 'Sin nombre');

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Contenido scrollable
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundImage:
                            _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                        child: _photoUrl == null
                            ? Text(
                                initial,
                                style: const TextStyle(fontSize: 28),
                              )
                            : null,
                      ),
                      const SizedBox(height: 10),
                      _cargandoNombre
                          ? const SizedBox(
                              height: 18,
                              child: Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            )
                          : Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Opciones
                _tile(
                  context,
                  title: 'Mis Datos',
                  onTap: _openEditProfile,
                ),
                _divider(),
                _tile(
                  context,
                  title: 'Ayuda y Soporte',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AyudaSoporteScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Botón de cerrar sesión
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _logout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Color(0xFFFFCDD2)),
                    backgroundColor: const Color(0xFFFFEBEE),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cerrar Sesión'),
                ),
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: ClienteBottomNav(
        currentIndex: 3, // Perfil
        onTap: (index) {
          if (index == 3) return;

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
        },
      ),
    );
  }

  Widget _tile(BuildContext ctx,
      {required String title, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _divider() => const SizedBox(height: 8);
}