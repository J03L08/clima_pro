import 'package:flutter/material.dart';
import 'package:clima_pro/views/home/home_cliente.dart';
import 'package:clima_pro/views/cliente/mis_solicitudes_screen.dart';
import 'package:clima_pro/views/home/perfil_screen.dart';
import 'package:clima_pro/widgets/cliente_bottom_nav.dart'; // 👈 nuevo import

class AvisosScreen extends StatefulWidget {
  const AvisosScreen({super.key});
  static const routeName = '/avisos';

  @override
  State<AvisosScreen> createState() => _AvisosScreenState();
}

class _AvisosScreenState extends State<AvisosScreen> {
  int unreadNotifications = 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Notificaciones',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),

          // --- Tarjetas de ejemplo ---
          _notifCard(
            title: 'Cita confirmada',
            subtitle: 'Tu servicio del 28 Oct ha sido confirmado',
            timeAgo: 'Hace 2h',
          ),
          _notifCard(
            title: 'Recordatorio',
            subtitle: 'Tienes un servicio mañana a las 10:00 AM',
            timeAgo: 'Hace 5h',
          ),
          _notifCard(
            title: 'Servicio completado',
            subtitle: 'Califica tu experiencia con Daniel Resendiz',
            timeAgo: 'Hace 1d',
          ),
        ],
      ),

      // 👇 Nuevo widget
      bottomNavigationBar: ClienteBottomNav(
        currentIndex: 2, // 2 = Avisos
        onTap: (index) {
          if (index == 2) return; // ya estás aquí

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

  Widget _notifCard({
    required String title,
    required String subtitle,
    required String timeAgo,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: CircleAvatar(
              radius: 5,
              backgroundColor: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(subtitle),
                const SizedBox(height: 6),
                Text(
                  timeAgo,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}