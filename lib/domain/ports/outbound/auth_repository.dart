import '../../entities/session.dart';
import '../../exceptions/app_failure.dart';
import '../../shared/result.dart';
import '../../value_objects/email.dart';
import '../../value_objects/password.dart';

/// Resultado de un intento de login: o bien una sesión completa, o el
/// servidor pide un OTP antes de continuar.
sealed class LoginOutcome {
  const LoginOutcome();
}

class LoginSucceeded extends LoginOutcome {
  final Session session;
  const LoginSucceeded(this.session);
}

class LoginRequiresOtp extends LoginOutcome {
  final Email email;
  const LoginRequiresOtp(this.email);
}

/// Puerto del repositorio de autenticación.
///
/// Cada método representa una capacidad atómica del backend de auth.
/// Las implementaciones (`HttpAuthRepository`) traducen llamadas a la API
/// en `Result` y nunca lanzan excepciones al dominio.
abstract interface class AuthRepository {
  /// Login email + password. Si el backend exige 2FA devuelve [LoginRequiresOtp].
  /// Si `biometric` es true, el servidor salta el OTP.
  Future<Result<LoginOutcome, AuthFailure>> login(
    Email email,
    Password password, {
    bool biometric = false,
  });

  /// Verifica un OTP (login o registro) y devuelve la sesión si fue válido.
  Future<Result<Session, AuthFailure>> verifyLoginOtp(Email email, String code);

  /// Registra un nuevo usuario. El backend responde 201 sin sesión todavía.
  Future<Result<void, AuthFailure>> register(Email email, Password password);

  /// Verifica el OTP de email tras un registro.
  Future<Result<void, AuthFailure>> verifyEmail(Email email, String code);

  /// Reenvía el OTP al correo dado.
  Future<Result<void, AuthFailure>> resendOtp(Email email);

  /// Solicita reseteo de contraseña.
  Future<Result<void, AuthFailure>> requestPasswordReset(Email email);

  /// Aplica un reseteo de contraseña con el OTP recibido.
  Future<Result<void, AuthFailure>> resetPassword({
    required Email email,
    required String code,
    required Password newPassword,
  });

  /// Notifica al backend de un logout (si falla no debe romper el flujo).
  Future<Result<void, AuthFailure>> notifyLogout();
}
