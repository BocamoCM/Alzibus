import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/exceptions/app_failure.dart';
import '../domain/shared/result.dart';
import '../presentation/providers/di.dart';
import '../core/router/app_router.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  final String email;

  const ResetPasswordPage({super.key, required this.email});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    final l = AppLocalizations.of(context)!;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final resetPassword = ref.read(resetPasswordProvider);
    final result = await resetPassword(
      rawEmail: widget.email,
      code: _codeController.text.trim(),
      rawNewPassword: _passwordController.text.trim(),
    );

    if (!mounted) return;

    switch (result) {
      case Ok():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.passwordResetSuccess)),
        );
        setState(() => _isLoading = false);
        const LoginRoute().go(context);
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
      ValidationFailure(fieldErrors: final errors) =>
        errors.values.isNotEmpty ? errors.values.first : l.enterCode,
      NetworkFailure() => l.noServerConnection,
      InvalidOtpFailure() => l.enterCode,
      RegistrationFailure(serverMessage: final msg) =>
        msg ?? 'No se pudo restablecer la contraseña.',
      _ => 'Error inesperado: ${failure.code}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.resetPasswordTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mark_email_read_outlined, size: 80, color: Colors.blue),
                const SizedBox(height: 24),
                Text(
                  '${l.codeSent}\n${widget.email}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: l.enterCode,
                    prefixIcon: const Icon(Icons.pin_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8),
                  validator: (value) {
                    if (value == null || value.trim().length != 6) {
                      return l.enterCode;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: l.newPassword,
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l.enterPassword;
                    }
                    if (value.length < 6) {
                      return l.passwordTooShort;
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
                          onPressed: _resetPassword,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(l.resetPasswordButton),
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
