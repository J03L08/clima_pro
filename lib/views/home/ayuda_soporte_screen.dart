import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AyudaSoporteScreen extends StatelessWidget {
  const AyudaSoporteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayuda y Soporte'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '¿Necesitas ayuda?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Aquí encontrarás algunas respuestas rápidas y cómo contactarnos '
            'en caso de que tengas algún problema con la app o con tus servicios.',
          ),
          const SizedBox(height: 24),

          const Text(
            'Preguntas frecuentes',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const ListTile(
            title: Text('No puedo iniciar sesión'),
            subtitle: Text(
              'Verifica tu conexión a internet y que el correo que utilizas sea el '
              'mismo con el que te registraste. Si el problema continúa, contáctanos.',
            ),
          ),
          const Divider(),
          const ListTile(
            title: Text('Mi técnico no llega a la hora acordada'),
            subtitle: Text(
              'Puedes revisar el estatus de tu servicio en la sección Agenda. '
              'Si hay un retraso, te enviaremos una notificación.',
            ),
          ),
          const Divider(),
          const ListTile(
            title: Text('¿Cómo reprogramo un servicio?'),
            subtitle: Text(
              'En la pantalla de Agenda selecciona tu servicio y utiliza la opción '
              '"Reprogramar".',
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Contacto',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const ListTile(
            leading: Icon(Icons.email_outlined),
            title: Text('Correo'),
            subtitle: Text('joelelias917@gmail.com'),
          ),
          const ListTile(
            leading: FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green),
            title: Text('WhatsApp'),
            subtitle: Text('+52 441 131 7870'),
          ),
          const ListTile(
            leading: Icon(Icons.phone),
            title: Text('Teléfono'),
            subtitle: Text('Lunes a viernes de 9:00 a 18:00 hrs'),
          ),
        ],
      ),
    );
  }
}