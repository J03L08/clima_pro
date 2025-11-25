import 'package:clima_pro/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _sending = false;
  bool _checking = false;
  String? _msg;

  Future<void> _send() async {
    setState(() { _sending = true; _msg = null; });
    try {
      await AuthService.instance.currentFbUser?.sendEmailVerification();
      _msg = 'Te enviamos un correo de verificación. Revisa tu bandeja o spam.';
    } on FirebaseAuthException catch (e) {
      _msg = 'No se pudo enviar: ${e.code}';
    } catch (_) {
      _msg = 'Ocurrió un error al enviar el correo.';
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _check() async {
    setState(() { _checking = true; _msg = null; });
    try {
      await AuthService.instance.reloadUser();
      final verified = AuthService.instance.currentFbUser?.emailVerified ?? false;
      if (verified) {
        if (!mounted) return;
        Navigator.of(context).pop(); // volver al AuthGate
      } else {
        _msg = 'Aún no está verificado. Abre el enlace del correo y vuelve a intentar.';
      }
    } catch (_) {
      _msg = 'No se pudo verificar el estado. Intenta de nuevo.';
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // Enviar automáticamente la primera vez
    _send();
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService.instance.currentFbUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifica tu correo'),
        actions: [
          TextButton(onPressed: () => AuthService.instance.signOut(), child: const Text('Salir')),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Hemos enviado un enlace de verificación a:\n$email', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                if (_msg != null) Text(_msg!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton(
                      onPressed: _sending ? null : _send,
                      child: _sending ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Reenviar correo'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: _checking ? null : _check,
                      child: _checking ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Ya verifiqué'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}