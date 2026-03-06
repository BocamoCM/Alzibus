import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import 'package:alzitrans/pages/otp_verification_page.dart';
import '../services/auth_service.dart';
import '../main.dart'; // import for HomePage
import 'register_page.dart';
import 'forgot_password_page.dart';
import '../constants/app_config.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

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
      await _authService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;
      
      // Finalizar contexto de autofill si no hay OTP (éxito directo)
      TextInput.finishAutofillContext();
      
      // Actualizar flag de publicidad según el estado premium del usuario
      final isPremium = await _authService.isUserPremium();
      AppConfig.showAds = !isPremium;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } on AuthLoginOtpRequiredException catch (e) {
      if (!mounted) return;
      
      // IMPORTANTE: Avisar al sistema de que "aquí" terminamos con el usuario/pass
      // para que salte el diálogo de guardar antes de que los campos desaparezcan.
      TextInput.finishAutofillContext();

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerificationPage(
            email: e.email,
            isLoginFlow: true,
          ),
        ),
      );
    } on AuthInvalidCredentialsException {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = l.incorrectCredentials;
      });
    } on AuthNetworkException {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = l.noServerConnection;
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
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _login,
                          child: Text(l.loginButton),
                        ),
                      ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterPage()),
                    );
                  },
                  child: Text(l.noAccount),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                    );
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
