import 'package:alzitrans/main.dart';
import 'package:go_router/go_router.dart';
import 'package:alzitrans/services/auth_service.dart';
import 'package:alzitrans/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/auth_provider.dart';
import '../services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/router/app_router.dart';

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

    try {
      String? error;
      final authService = ref.read(authServiceProvider);
      if (widget.isLoginFlow) {
        error = await authService.verifyLoginCode(widget.email, code);
      } else {
        error = await authService.verifyEmail(widget.email, code);
      }
      
      if (!mounted) return;

      if (error != null) {
        _showError(error);
      } else {
        // Notificar al sistema que la autenticación terminó con éxito (para guardar contraseña)
        TextInput.finishAutofillContext();
        
        if (widget.isLoginFlow) {
          // COMPROBAR BIOMETRÍA TRAS LOGIN EXITOSO
          final canCheck = await authService.canCheckBiometrics();
          final isEnabled = await authService.isBiometricEnabled();
          
          if (canCheck && !isEnabled && mounted) {
            final setupBiometrics = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('¿Activar Huella?'),
                content: const Text('¿Quieres entrar más rápido la próxima vez usando tu huella dactilar?'),
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

            if (setupBiometrics == true) {
              // Necesitamos la contraseña del login anterior. 
              // Como no la tenemos aquí, una opción es pedirla o haberla guardado temporalmente.
              // Para simplificar, asumiremos que el AuthService tiene una forma de 
              // obtenerla o que el usuario la introducirá una última vez si es necesario.
              // Pero lo ideal es que el login_page la pase o el servicio la cachee.
              // SOLUCIÓN: El login_page debería pasarla o el AuthService guardarla 
              // temporalmente hasta este punto.
              
              // Por ahora, mostraremos un mensaje indicando que se activará en el próximo login manual exitoso
              // O mejor, el AuthService la guarda en el login() y aquí la persistimos.
              await authService.persistBiometricCredentials();
              if (mounted) _showSuccess('¡Acceso biométrico activado!');
            }
          }

          if (mounted) {
            await ref.read(authProvider.notifier).checkLogin();
            if (!mounted) return;
            _showSuccess('¡Sesión iniciada correctamente!');
            // La redirección está controlada por GoRouter, pero la forzamos para navegación explícita.
            const HomeRoute().go(context);
          }
        } else {
          _showSuccess('¡Correo verificado! Ya puedes iniciar sesión.');
          const LoginRoute().go(context);
        }
      }
    } on AuthNetworkException {
      if (mounted) _showError('Sin conexión al servidor.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    if (_resendsLeft <= 0) {
      _showError('Has agotado los reenvíos disponibles.');
      return;
    }

    setState(() => _isResending = true);

    try {
      final authService = ref.read(authServiceProvider);
      final error = await authService.resendOtp(widget.email);
      if (!mounted) return;

      if (error != null) {
        _showError(error);
      } else {
        setState(() => _resendsLeft--);
        _codeController.clear();
        _showSuccess('Nuevo código enviado. Caduca en 15 minutos.');
      }
    } on AuthNetworkException {
      if (mounted) _showError('Sin conexión al servidor.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
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
