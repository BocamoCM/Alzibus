import '../../domain/entities/session.dart';
import '../../domain/entities/user.dart';
import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/auth_repository.dart';
import '../../domain/ports/outbound/http_port.dart';
import '../../domain/shared/result.dart';
import '../../domain/value_objects/email.dart';
import '../../domain/value_objects/jwt_token.dart';
import '../../domain/value_objects/password.dart';

/// Adaptador HTTP de [AuthRepository]. Habla con los endpoints existentes
/// del backend Node.js de Alzitrans (`/login`, `/login/verify`, `/register`,
/// `/verify-email`, `/resend-otp`, `/forgot-password`, `/reset-password`,
/// `/users/logout`).
///
/// Mapea la respuesta a un `Result<…, AuthFailure>` aplicando las reglas:
/// - 200 con `token`           → [LoginSucceeded]
/// - 200 con `requiresOtp`     → [LoginRequiresOtp]
/// - 401/403                   → [InvalidCredentialsFailure]
/// - 403 con "verificar tu correo" → [EmailNotVerifiedFailure]
/// - timeout/offline           → propagado como [AuthFailure] envolviendo el [NetworkFailure]
class HttpAuthRepository implements AuthRepository {
  final HttpPort _http;
  const HttpAuthRepository(this._http);

  // ───────── Login ─────────

  @override
  Future<Result<LoginOutcome, AuthFailure>> login(
    Email email,
    Password password, {
    bool biometric = false,
  }) async {
    final response = await _http.post('/login', body: {
      'email': email.value,
      'password': password.value,
      if (biometric) 'biometric': true,
    });

    switch (response) {
      case Err(failure: final f):
        return Err(_networkToAuth(f));
      case Ok(value: final r):
        if (r.statusCode == 200) {
          final body = r.bodyAsMap;
          if (body == null) {
            return const Err(InvalidCredentialsFailure());
          }
          if (body['token'] != null) {
            return _buildLoginSucceeded(body);
          }
          if (body['requiresOtp'] == true) {
            final emailRaw = body['email'] as String? ?? email.value;
            final parsed = Email.tryParse(emailRaw);
            final em = parsed is Ok<Email, ValidationFailure>
                ? parsed.value
                : email;
            return Ok(LoginRequiresOtp(em));
          }
          return const Err(InvalidCredentialsFailure());
        }
        if (r.statusCode == 403 &&
            (r.errorMessage ?? '').toLowerCase().contains('verificar tu correo')) {
          return const Err(EmailNotVerifiedFailure());
        }
        return const Err(InvalidCredentialsFailure());
    }
  }

  @override
  Future<Result<Session, AuthFailure>> verifyLoginOtp(
    Email email,
    String code,
  ) async {
    final response = await _http.post('/login/verify', body: {
      'email': email.value,
      'code': code,
    });
    switch (response) {
      case Err(failure: final f):
        return Err(_networkToAuth(f));
      case Ok(value: final r):
        if (r.statusCode == 200) {
          final body = r.bodyAsMap;
          if (body == null) return const Err(InvalidOtpFailure());
          final outcome = _buildLoginSucceeded(body);
          switch (outcome) {
            case Err(failure: final f):
              return Err(f);
            case Ok(value: final ok):
              if (ok is LoginSucceeded) return Ok(ok.session);
              return const Err(InvalidOtpFailure());
          }
        }
        return const Err(InvalidOtpFailure());
    }
  }

  // ───────── Registro ─────────

  @override
  Future<Result<void, AuthFailure>> register(
    Email email,
    Password password,
  ) async {
    final response = await _http.post('/register', body: {
      'email': email.value,
      'password': password.value,
    });
    switch (response) {
      case Err(failure: final f):
        return Err(_networkToAuth(f));
      case Ok(value: final r):
        if (r.statusCode == 201) return const Ok(null);
        return Err(RegistrationFailure(serverMessage: r.errorMessage));
    }
  }

  @override
  Future<Result<void, AuthFailure>> verifyEmail(Email email, String code) async {
    final response = await _http.post('/verify-email', body: {
      'email': email.value,
      'code': code,
    });
    switch (response) {
      case Err(failure: final f):
        return Err(_networkToAuth(f));
      case Ok(value: final r):
        if (r.statusCode == 200) return const Ok(null);
        return const Err(InvalidOtpFailure());
    }
  }

  @override
  Future<Result<void, AuthFailure>> resendOtp(Email email) async {
    final response = await _http.post('/resend-otp', body: {
      'email': email.value,
    });
    switch (response) {
      case Err(failure: final f):
        return Err(_networkToAuth(f));
      case Ok(value: final r):
        if (r.statusCode == 200) return const Ok(null);
        return Err(RegistrationFailure(serverMessage: r.errorMessage));
    }
  }

  // ───────── Reseteo de contraseña ─────────

  @override
  Future<Result<void, AuthFailure>> requestPasswordReset(Email email) async {
    final response = await _http.post('/forgot-password', body: {
      'email': email.value,
    });
    switch (response) {
      case Err(failure: final f):
        return Err(_networkToAuth(f));
      case Ok(value: final r):
        if (r.statusCode == 200) return const Ok(null);
        return Err(RegistrationFailure(serverMessage: r.errorMessage));
    }
  }

  @override
  Future<Result<void, AuthFailure>> resetPassword({
    required Email email,
    required String code,
    required Password newPassword,
  }) async {
    final response = await _http.post('/reset-password', body: {
      'email': email.value,
      'code': code,
      'newPassword': newPassword.value,
    });
    switch (response) {
      case Err(failure: final f):
        return Err(_networkToAuth(f));
      case Ok(value: final r):
        if (r.statusCode == 200) return const Ok(null);
        return Err(RegistrationFailure(serverMessage: r.errorMessage));
    }
  }

  // ───────── Logout ─────────

  @override
  Future<Result<void, AuthFailure>> notifyLogout() async {
    final response = await _http.post('/users/logout');
    switch (response) {
      case Err(failure: final f):
        return Err(_networkToAuth(f));
      case Ok():
        return const Ok(null); // ignoramos status: best-effort
    }
  }

  @override
  Future<Result<void, AuthFailure>> deleteAccount() async {
    final response = await _http.delete('/users/profile');
    switch (response) {
      case Err(failure: final f):
        return Err(_networkToAuth(f));
      case Ok(value: final r):
        if (r.statusCode == 200) return const Ok(null);
        return Err(RegistrationFailure(serverMessage: r.errorMessage));
    }
  }

  // ───────── Helpers ─────────

  /// Construye una `LoginSucceeded` a partir del body de respuesta del backend.
  Result<LoginOutcome, AuthFailure> _buildLoginSucceeded(
    Map<String, dynamic> body,
  ) {
    final tokenRaw = body['token'];
    if (tokenRaw is! String) return const Err(InvalidCredentialsFailure());

    final tokenResult = JwtToken.tryParse(tokenRaw);
    if (tokenResult case Err(failure: final f)) return Err(f);

    final userMap = body['user'];
    if (userMap is! Map) return const Err(InvalidCredentialsFailure());

    final emailRaw = userMap['email'];
    final id = userMap['id'];
    final isPremium = userMap['isPremium'] as bool? ?? false;
    if (emailRaw is! String || id is! int) {
      return const Err(InvalidCredentialsFailure());
    }
    final emailVo = Email.tryParse(emailRaw);
    if (emailVo case Err()) return const Err(InvalidCredentialsFailure());
    final session = Session(
      user: User(id: id, email: emailVo.unwrap(), isPremium: isPremium),
      token: tokenResult.unwrap(),
    );
    return Ok(LoginSucceeded(session));
  }

  /// Mapea un fallo de red a un fallo de Auth, conservando la causa para
  /// que el `LoggerPort` lo registre en Sentry.
  AuthFailure _networkToAuth(NetworkFailure f) {
    // Reutilizamos `RegistrationFailure` con código distinto sería confuso;
    // creamos uno específico de sesión expirada para 401, y agrupamos el
    // resto bajo una causa de red. La capa de UI mapea ambos a strings.
    if (f is ServerFailure && f.statusCode == 401) {
      return const SessionExpiredFailure();
    }
    return NetworkAuthFailure(f);
  }
}
