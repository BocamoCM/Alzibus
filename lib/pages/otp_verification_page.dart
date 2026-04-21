import 'package:alzitrans/main.dart';
import 'package:go_router/go_router.dart';
import 'package:alzitrans/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/providers/auth_provider.dart';
import '../core/router/app_router.dart';
import '../domain/exceptions/app_failure.dart';
import '../domain/shared/result.dart';
import '../domain/value_objects/email.dart';
import '../presentation/providers/di.dart';

/// Página de verificación OTP — migrada a la arquitectura hexagonal.
///
/// Flujos:
/// - `isLoginFlow=true`  → 2FA tras login con password → [verifyLoginOtpProvider].
/// - `isLoginFlow=false` → verificación de email tras registro → usa el
///   [authRepositoryProvider.verifyEmail] directamente (no hay use case todavía).
///
/// Tras un login OTP exitoso, si el dispositivo soporta biometría y aún no hay
/// credenciales guardadas, se ofrece activarla y se persisten vía
/// [enableBiometricsProvider] usando las credenciales cacheadas en
/// [pendingLoginCredentialsProvider] por la pantalla de login.
class OtpVerificationPage extends ConsumerStatefulWidget {
  final String email;
  final bool isLoginFlow;

  const OtpVerificationPage({
    super.key,
    required this.email,
    this.isLoginFlow = false,
  });

  @override
  ConsumerState<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends ConsumerState<OtpVerificationPage> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  int _resendsLeft = 3;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AlzitransColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _showError('El código debe tener 6 dígitos');
      return;
    }

    setState(() => _isLoading = true);

    if (widget.isLoginFlow) {
      await _verifyLoginOtp(code);
    } else {
      await _verifyEmail(code);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _verifyLoginOtp(String code) async {
    final verifyLoginOtp = ref.read(verifyLoginOtpProvider);
    final result = await verifyLoginOtp(
      rawEmail: widget.email,
      code: code,
    );
    if (!mounted) return;

    switch (result) {
      case Err(failure: final f):
        _showError(_mapFailureToMessage(f));
        return;
      case Ok():
        TextInput.finishAutofillContext();
        await _afterLoginOtpSuccess();
        return;
    }
  }

  Future<void> _afterLoginOtpSuccess() async {
    // Comprobar biometría tras login exitoso.
    final authenticator = ref.read(biometricAuthenticatorProvider);
    final credsStorage = ref.read(biometricCredentialsStorageProvider);
    final canCheck = await authenticator.isAvailable();
    final isEnabled = await credsStorage.isEnabled();

    if (canCheck && !isEnabled && mounted) {
      final setup = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('¿Activar Huella?'),
          content: const Text(
            '¿Quieres entrar más rápido la próxima vez usando tu huella dactilar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ahora no'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('¡Sí, activar!'),
            ),
          ],
        ),
      );

      if (setup == true) {
        final pending = ref.read(pendingLoginCredentialsProvider);
        if (pending != null) {
          final enable = ref.read(enableBiometricsProvider);
          final saved = await enable(
            rawEmail: pending.email,
            rawPassword: pending.password,
          );
          if (saved case Ok()) {
            if (mounted) _showSuccess('¡Acceso biométrico activado!');
          } else if (mounted) {
            _showError('No se pudo activar la biometría.');
          }
        }
      }
    }

    // En cualquier caso limpiamos las credenciales cacheadas.
    ref.read(pendingLoginCredentialsProvider.notifier).state = null;

    if (!mounted) return;
    await ref.read(authProvider.notifier).checkLogin();
    if (!mounted) return;
    _showSuccess('¡Sesión iniciada correctamente!');
    const HomeRoute().go(context);
  }

  Future<void> _verifyEmail(String code) async {
    final emailVo = Email.tryParse(widget.email);
    if (emailVo case Err()) {
      _showError('Email inválido.');
      return;
    }
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.verifyEmail(emailVo.unwrap(), code);
    if (!mounted) return;

    switch (result) {
      case Err(failure: final f):
        _showError(_mapFailureToMessage(f));
        return;
      case Ok():
        TextInput.finishAutofillContext();
        _showSuccess('¡Correo verificado! Ya puedes iniciar sesión.');
        const LoginRoute().go(context);
        return;
    }
  }

  Future<void> _resendCode() async {
    if (_resendsLeft <= 0) {
      _showError('Has agotado los reenvíos disponibles.');
      return;
    }

    setState(() => _isResending = true);

    final emailVo = Email.tryParse(widget.email);
    if (emailVo case Err()) {
      setState(() => _isResending = false);
      _showError('Email inválido.');
      return;
    }

    final repo = ref.read(authRepositoryProvider);
    final result = await repo.resendOtp(emailVo.unwrap());
    if (!mounted) return;

    switch (result) {
      case Err(failure: final f):
        _showError(_mapFailureToMessage(f));
        break;
      case Ok():
        setState(() => _resendsLeft--);
        _codeController.clear();
        _showSuccess('Nuevo código enviado. Caduca en 15 minutos.');
        break;
    }

    if (mounted) setState(() => _isResending = false);
  }

  String _mapFailureToMessage(AppFailure failure) {
    return switch (failure) {
      InvalidOtpFailure() => 'Código incorrecto o expirado.',
      InvalidCredentialsFailure() => 'Código incorrecto.',
      EmailNotVerifiedFailure() => 'Debes verificar tu correo.',
      RegistrationFailure(serverMessage: final msg) =>
        msg ?? 'No se pudo completar la operación.',
      ValidationFailure(fieldErrors: final errors) =>
        errors.values.isNotEmpty ? errors.values.first : 'Código inválido.',
      NetworkFailure() => 'Sin conexión al servidor.',
      _ => 'Error inesperado: ${failure.code}',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificar Correo'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              const Icon(
                Icons.mark_email_unread_rounded,
                size: 80,
                color: AlzitransColors.burgundy,
              ),
              const SizedBox(height: 24),
              Text(
                'Confirma tu correo',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AlzitransColors.burgundy,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Hemos enviado un código de 6 dígitos a:\n${widget.email}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'El código caduca en 15 minutos.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  letterSpacing: 10,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: '------',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AlzitransColors.burgundy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Verificar Código',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 20),
              // Botón reenviar
              TextButton.icon(
                onPressed: (_isResending || _resendsLeft <= 0) ? null : _resendCode,
                icon: _isResending
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(
                  _resendsLeft > 0
                      ? 'Reenviar código (${_resendsLeft} restante${_resendsLeft == 1 ? '' : 's'})'
                      : 'Sin reenvíos disponibles',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
