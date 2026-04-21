import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/exceptions/app_failure.dart';
import '../domain/shared/result.dart';
import '../presentation/providers/di.dart';
import '../core/router/app_router.dart';

/// Página de registro — migrada a la arquitectura hexagonal.
///
/// Usa [registerUserProvider] y mapea los [AppFailure] a mensajes de UI
/// equivalentes a los que devolvía la API legacy.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _message = '';
  bool _success = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _message = '';
      _success = false;
    });

    final registerUser = ref.read(registerUserProvider);
    final result = await registerUser(
      rawEmail: _emailController.text.trim(),
      rawPassword: _passwordController.text.trim(),
    );

    if (!mounted) return;

    switch (result) {
      case Ok():
        TextInput.finishAutofillContext();
        setState(() => _isLoading = false);
        if (mounted) {
          VerifyRoute(email: _emailController.text.trim()).pushReplacement(context);
        }
        return;
      case Err(failure: final f):
        setState(() {
          _isLoading = false;
          _message = _mapFailureToMessage(f);
        });
        return;
    }
  }

  String _mapFailureToMessage(AppFailure failure) {
    return switch (failure) {
      RegistrationFailure(serverMessage: final msg) =>
        msg ?? 'No se pudo completar el registro.',
      ValidationFailure(fieldErrors: final errors) =>
        errors.values.isNotEmpty ? errors.values.first : 'Datos inválidos.',
      NetworkFailure() => 'Sin conexión al servidor. Comprueba tu red.',
      _ => 'Error inesperado: ${failure.code}',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro en Alzibus')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Introduce tu email';
                    }
                    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'El email no tiene un formato válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _register(),
                  autofillHints: const [AutofillHints.password],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Introduce tu contraseña';
                    }
                    if (value.length < 6) {
                      return 'La contraseña debe tener al menos 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                if (_message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _message,
                      style: TextStyle(
                        color: _success ? Colors.green : Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                _isLoading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _register,
                          child: const Text('Registrarse'),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
