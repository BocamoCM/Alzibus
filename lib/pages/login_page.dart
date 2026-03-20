import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import 'package:alzitrans/pages/otp_verification_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../main.dart'; // import for HomePage
import 'register_page.dart';
import 'forgot_password_page.dart';
import '../constants/app_config.dart';
import '../core/router/app_router.dart';

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
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final authService = ref.read(authServiceProvider);
    final canCheck = await authService.canCheckBiometrics();
    final isEnabled = await authService.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _canCheckBiometrics = canCheck && isEnabled;
      });
      
      // Intentar login automático si está habilitado
      if (_canCheckBiometrics) {
        _loginWithBiometrics();
      }
    }
  }

  Future<void> _loginWithBiometrics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authService = ref.read(authServiceProvider);
      final success = await authService.loginWithBiometrics();
      if (success) {
        await ref.read(authProvider.notifier).checkLogin();
        if (!mounted) return;
        // La redirección a home se maneja automáticamente por GoRouter gracias al authProvider.
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            // No mostramos error aquí para no molestar si solo falló el escaneo
          });
        }
      }
    } on AuthLoginOtpRequiredException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      VerifyRoute(email: e.email, isLoginFlow: true).push(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error en acceso biométrico: $e';
        });
      }
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

    try {
      final authService = ref.read(authServiceProvider);
      await authService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      debugPrint('[LoginPage] Login finalizado sin excepción');
      if (!mounted) return;
      
      // Finalizar contexto de autofill si no hay OTP (éxito directo)
      TextInput.finishAutofillContext();
      
      // Actualizar flag de publicidad según el estado premium del usuario
      final isPremium = await authService.isUserPremium();
      AppConfig.showAds = !isPremium;

      await ref.read(authProvider.notifier).checkLogin();
      // La redirección a home se maneja automáticamente por GoRouter gracias al authProvider.
    } on AuthLoginOtpRequiredException catch (e) {
      debugPrint('[LoginPage] AuthLoginOtpRequiredException capturada para: ${e.email}');
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      // IMPORTANTE: Avisar al sistema de que "aquí" terminamos con el usuario/pass
      // para que salte el diálogo de guardar antes de que los campos desaparezcan.
      TextInput.finishAutofillContext();

      VerifyRoute(email: e.email, isLoginFlow: true).push(context);
    } on AuthInvalidCredentialsException {
      debugPrint('[LoginPage] AuthInvalidCredentialsException capturada');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = l.incorrectCredentials;
      });
    } on AuthNetworkException catch (e) {
      debugPrint('[LoginPage] AuthNetworkException capturada: ${e.cause}');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = l.noServerConnection;
      });
    } catch (e) {
      debugPrint('[LoginPage] Otra excepción capturada: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error inesperado: $e';
      });
    }
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
                          if (_canCheckBiometrics) ...[
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
