import 'package:clima_pro/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:clima_pro/views/auth/verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();

  bool _loading = false;
  String? _error;

  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  InputDecoration _decor({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)), // gris claro
    );

    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      prefixIcon: Icon(icon, color: Colors.blueGrey.shade400),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xFFE11D48)),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xFFE11D48)),
      ),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.registerWithEmail(
        email: _email.text.trim(),
        password: _pass.text.trim(),
      );

      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      final code = e.code;
      if (code == 'email-already-in-use') {
        _error = 'Ese correo ya está registrado.';
      } else if (code == 'invalid-email') {
        _error = 'Correo inválido.';
      } else if (code == 'weak-password') {
        _error = 'Contraseña muy débil.';
      } else {
        _error = 'Ocurrió un error. Inténtalo de nuevo.';
      }
      setState(() {});
    } catch (_) {
      _error = 'Ocurrió un error. Inténtalo de nuevo.';
      setState(() {});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF6F8FB),
              Color(0xFFF1F5F9),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  // Encabezado visual sutil
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded,
                            size: 28, color: Color(0xFF475569)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Crear una cuenta',
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          Text('Regístrate para empezar a usar ClimaPro',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: Colors.blueGrey)),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Card(
                    elevation: 2,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            if (_error != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE4E6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFFCA5A5)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: Color(0xFFB91C1C)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                                color:
                                                    const Color(0xFF7F1D1D)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],

                            TextFormField(
                              controller: _email,
                              decoration: _decor(
                                  label: 'Correo',
                                  icon: Icons.mail_outline_rounded),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => (v == null || !v.contains('@'))
                                  ? 'Correo inválido'
                                  : null,
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _pass,
                              obscureText: _obscure1,
                              decoration: _decor(
                                label: 'Contraseña',
                                icon: Icons.lock_outline_rounded,
                                suffix: IconButton(
                                  onPressed: () =>
                                      setState(() => _obscure1 = !_obscure1),
                                  icon: Icon(_obscure1
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                  tooltip: _obscure1 ? 'Mostrar' : 'Ocultar',
                                ),
                              ),
                              validator: (v) => (v == null || v.length < 6)
                                  ? 'Mínimo 6 caracteres'
                                  : null,
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _pass2,
                              obscureText: _obscure2,
                              decoration: _decor(
                                label: 'Confirmar contraseña',
                                icon: Icons.lock_person_outlined,
                                suffix: IconButton(
                                  onPressed: () =>
                                      setState(() => _obscure2 = !_obscure2),
                                  icon: Icon(_obscure2
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                  tooltip: _obscure2 ? 'Mostrar' : 'Ocultar',
                                ),
                              ),
                              validator: (v) => (v == null || v != _pass.text)
                                  ? 'Las contraseñas no coinciden'
                                  : null,
                            ),

                            const SizedBox(height: 16),

                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton(
                                onPressed: _loading ? null : _register,
                                child: _loading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Text('Crear cuenta'),
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
      ),
    );
  }
}