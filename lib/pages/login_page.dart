import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/auth_provider.dart';
import '../domain/exceptions/app_failure.dart';
import '../domain/ports/outbound/auth_repository.dart';
import '../domain/shared/result.dart';
import '../presentation/providers/di.dart';
import 'register_page.dart';
import 'forgot_password_page.dart';
import '../constants/app_config.dart';
import '../core/router/app_router.dart';

/// Página de login — versión migrada a la arquitectura hexagonal.
///
/// Consume los providers de `presentation/providers/di.dart`:
/// - [loginWithPasswordProvider] → email + password.
/// - [loginWithBiometricsProvider] → huella/face con credenciales cacheadas.
/// - [biometricCredentialsStorageProvider] / [biometricAuthenticatorProvider]
///   para decidir si mostrar el botón de biometría.
///
/// Los `Result<..., AppFailure>` se mapean a los mismos textos localizados que
/// se usaban con la API legacy basada en excepciones.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';
  bool _canUseBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final credentialsStorage = ref.read(biometricCredentialsStorageProvider);
    final authenticator = ref.read(biometricAuthenticatorProvider);

    final isEnabled = await credentialsStorage.isEnabled();
    final canCheck = await authenticator.isAvailable();

    if (!mounted) return;
    setState(() {
      _canUseBiometrics = canCheck && isEnabled;
    });

    if (_canUseBiometrics) {
      _loginWithBiometrics();
    }
  }

  Future<void> _loginWithBiometrics() async {
    final l = AppLocalizations.of(context)!;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final loginWithBiometrics = ref.read(loginWithBiometricsProvider);
    final result = await loginWithBiometrics(
      reason: 'Alzitrans – verify your identity / verifica tu identidad',
    );

    if (!mounted) return;

    switch (result) {
      case Ok(value: BiometricSucceeded()):
        await _onLoginSucceeded();
        return;
      case Ok(value: BiometricNotConfigured()):
      case Ok(value: BiometricCancelled()):
        // No mostramos error al usuario: puede ser que haya cancelado o que
        // simplemente no haya credenciales guardadas.
        setState(() => _isLoading = false);
        return;
      case Err(failure: final f):
        setState(() {
          _isLoading = false;
          _errorMessage = _mapFailureToMessage(f, l);
        });
        return;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final l = AppLocalizations.of(context)!;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final rawEmail = _emailController.text.trim();
    final rawPassword = _passwordController.text.trim();

    final loginWithPassword = ref.read(loginWithPasswordProvider);
    final result = await loginWithPassword(
      rawEmail: rawEmail,
      rawPassword: rawPassword,
    );

    if (!mounted) return;

    switch (result) {
      case Ok(value: LoginSucceeded()):
        // Guardamos las credenciales pendientes por si tras OTP o directamente
        // se ofrece activar biometría.
        ref.read(pendingLoginCredentialsProvider.notifier).state =
            PendingLoginCredentials(email: rawEmail, password: rawPassword);
        TextInput.finishAutofillContext();
        await _onLoginSucceeded();
        return;

      case Ok(value: LoginRequiresOtp(:final email)):
        // Guardamos las credenciales: la OTP page las leerá si el usuario
        // decide activar biometría tras verificar.
        ref.read(pendingLoginCredentialsProvider.notifier).state =
            PendingLoginCredentials(email: rawEmail, password: rawPassword);

        setState(() => _isLoading = false);
        TextInput.finishAutofillContext();

        VerifyRoute(email: email.value, isLoginFlow: true).push(context);
        return;

      case Err(failure: final f):
        setState(() {
          _isLoading = false;
          _errorMessage = _mapFailureToMessage(f, l);
        });
        return;
    }
  }

  Future<void> _onLoginSucceeded() async {
    // Actualizar flag de publicidad según el estado premium leído desde
    // SessionStorage (sin depender de AuthService legacy).
    final sessionStorage = ref.read(sessionStorageProvider);
    final sessionResult = await sessionStorage.read();
    if (sessionResult case Ok(value: final session)) {
      final isPremium = session?.user.isPremium ?? false;
      AppConfig.showAds = !isPremium;
    }

    await ref.read(authProvider.notifier).checkLogin();
    // La redirección a home la gestiona GoRouter reaccionando a authProvider.
  }

  /// Traduce un [AppFailure] al texto que ve el usuario. Mantiene las mismas
  /// cadenas localizadas que ya se usaban con la API de excepciones legacy.
  String _mapFailureToMessage(AppFailure failure, AppLocalizations l) {
    return switch (failure) {
      InvalidCredentialsFailure() => l.incorrectCredentials,
      OtpRequiredFailure() => l.incorrectCredentials,
      InvalidOtpFailure() => l.incorrectCredentials,
      EmailNotVerifiedFailure() =>
        'Debes verificar tu correo antes de iniciar sesión.',
      BiometricUnavailableFailure() =>
        'La autenticación biométrica no está disponible.',
      SessionExpiredFailure() => l.incorrectCredentials,
      ValidationFailure(fieldErrors: final errors) =>
        errors.values.isNotEmpty ? errors.values.first : l.incorrectCredentials,
      NetworkFailure() => l.noServerConnection,
      _ => 'Error inesperado: ${failure.code}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.loginTitle)),
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
                  decoration: InputDecoration(
                    labelText: l.email,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l.enterEmail;
                    }
                    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return l.invalidEmail;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: l.password,
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
                  onFieldSubmitted: (_) => _login(),
                  autofillHints: const [AutofillHints.password],
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
                    : Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _login,
                              child: Text(l.loginButton),
                            ),
                          ),
                          if (_canUseBiometrics) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _loginWithBiometrics,
                              icon: const Icon(Icons.fingerprint),
                              label: const Text('Entrar con huella'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 45),
                              ),
                            ),
                          ],
                        ],
                      ),
                TextButton(
                  onPressed: () {
                    const RegisterRoute().push(context);
                  },
                  child: Text(l.noAccount),
                ),
                TextButton(
                  onPressed: () {
                    const ForgotPasswordRoute().push(context);
                  },
                  child: Text(l.forgotPassword),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
