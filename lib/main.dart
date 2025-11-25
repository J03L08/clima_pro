import 'package:clima_pro/firebase_options.dart';
import 'package:clima_pro/services/auth_service.dart';
import 'package:clima_pro/views/auth/login_screen.dart';
import 'package:clima_pro/views/auth/role_selector_screen.dart';
import 'package:clima_pro/views/auth/verify_email_screen.dart';
import 'package:clima_pro/views/home/home_admin.dart';
import 'package:clima_pro/views/home/home_cliente.dart';
import 'package:clima_pro/views/home/home_tecnico.dart';
import 'package:clima_pro/views/cliente/nueva_solicitud_screen.dart'; // 👈 registra la pantalla para la ruta
import 'package:clima_pro/views/cliente/mis_solicitudes_screen.dart'; // 👈 import
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:clima_pro/views/home/avisos_screen.dart';
import 'package:clima_pro/views/home/perfil_screen.dart';

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage m) async {
  // opcional: inicializa Firebase si hace falta y maneja datos
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_bgHandler);

  runApp(const ClimaProApp());
}

class ClimaProApp extends StatelessWidget {
  const ClimaProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ClimaPro',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      // 🔹 Home se mantiene con tu AuthGate
      home: const _AuthGate(),

      // 🔹 Registro de rutas con nombre
      routes: {
        // Ruta para la pantalla a la que navega el botón "Solicitar Servicio"
        NuevaSolicitudScreen.routeName: (context) => const NuevaSolicitudScreen(),
        MisSolicitudesScreen.routeName: (context) => const MisSolicitudesScreen(),
        AvisosScreen.routeName: (context) => const AvisosScreen(),
        PerfilScreen.routeName: (context) => const PerfilScreen(),

        // (Opcionales) Si en algún momento decides navegar por nombre a estos:
        // '/home-cliente': (context) => const HomeCliente(),
        // '/home-tecnico': (context) => const HomeTecnico(),
        // '/home-admin': (context) => const HomeAdmin(),
        // '/login': (context) => const LoginScreen(),
        // '/verify-email': (context) => const VerifyEmailScreen(),
        // '/select-role': (context) => const RoleSelectorScreen(),
      },
      // onUnknownRoute: (settings) => MaterialPageRoute(
      //   builder: (_) => const HomeCliente(),
      // ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final _auth = AuthService.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthUser?>(
      stream: _auth.userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snapshot.data;
        if (user == null) return const LoginScreen();

        // 👇 Bloquea si no está verificado
        final isVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
        if (!isVerified) return const VerifyEmailScreen();

        if (user.role == null || user.role!.isEmpty) return const RoleSelectorScreen();

        switch (user.role) {
          case 'cliente':
            return const HomeCliente();
          case 'tecnico':
            return const HomeTecnico();
          case 'admin':
            return const HomeAdmin();
          default:
            return const RoleSelectorScreen();
        }
      },
    );
  }
}