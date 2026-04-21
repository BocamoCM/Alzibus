import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/exceptions/app_failure.dart';
import '../domain/shared/result.dart';
import '../presentation/providers/di.dart';
import 'reset_password_page.dart';
import '../core/router/app_router.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _requestReset() async {
    if (!_formKey.currentState!.validate()) return;
    final l = AppLocalizations.of(context)!;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final email = _emailController.text.trim();
    final requestReset = ref.read(requestPasswordResetProvider);
    final result = await requestReset(rawEmail: email);

    if (!mounted) return;

    switch (result) {
      case Ok():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.codeSent)),
        );
        setState(() => _isLoading = false);
        ResetPasswordRoute(email: email).push(context);
        return;
      case Err(failure: final f):
        setState(() {
          _isLoading = false;
          _errorMessage = _mapFailureToMessage(f, l);
        });
        return;
    }
  }

  String _mapFailureToMessage(AppFailure failure, AppLocalizations l) {
    return switch (failure) {
      ValidationFailure() => l.invalidEmail,
      NetworkFailure() => l.noServerConnection,
      RegistrationFailure(serverMessage: final msg) =>
        msg ?? 'No se pudo solicitar el código.',
      _ => 'Error inesperado: ${failure.code}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.forgotPasswordTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_reset, size: 80, color: Colors.blue),
                const SizedBox(height: 24),
                Text(
                  l.forgotPasswordInstructions,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: l.email,
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l.enterEmail;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                _isLoading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _requestReset,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(l.sendCode),
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
