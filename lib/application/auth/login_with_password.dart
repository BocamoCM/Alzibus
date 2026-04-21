import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/auth_repository.dart';
import '../../domain/ports/outbound/logger_port.dart';
import '../../domain/ports/outbound/session_storage.dart';
import '../../domain/shared/result.dart';
import '../../domain/value_objects/email.dart';
import '../../domain/value_objects/password.dart';

/// Caso de uso: login clásico con email + password.
///
/// Flujo:
/// 1. Valida y construye los Value Objects (puede fallar con [ValidationFailure]).
/// 2. Pide login al repositorio.
/// 3. Si el resultado es [LoginSucceeded], guarda la sesión.
/// 4. Si es [LoginRequiresOtp], lo propaga al UI sin guardar nada.
/// 5. Cualquier `AppFailure` se loguea por el [LoggerPort] antes de devolverse.
class LoginWithPassword {
  final AuthRepository _authRepository;
  final SessionStorage _sessionStorage;
  final LoggerPort _logger;

  const LoginWithPassword({
    required AuthRepository authRepository,
    required SessionStorage sessionStorage,
    required LoggerPort logger,
  })  : _authRepository = authRepository,
        _sessionStorage = sessionStorage,
        _logger = logger;

  Future<Result<LoginOutcome, AppFailure>> call({
    required String rawEmail,
    required String rawPassword,
    bool biometric = false,
  }) async {
    final emailResult = Email.tryParse(rawEmail);
    final passwordResult = Password.tryParse(rawPassword);
    if (emailResult case Err(failure: final f)) return Err(f);
    if (passwordResult case Err(failure: final f)) return Err(f);

    final email = emailResult.unwrap();
    final password = passwordResult.unwrap();

    final loginResult = await _authRepository.login(
      email,
      password,
      biometric: biometric,
    );

    switch (loginResult) {
      case Err(failure: final f):
        await _logger.captureFailure(f);
        return Err(f);
      case Ok(value: final outcome):
        if (outcome is LoginSucceeded) {
          final saved = await _sessionStorage.save(outcome.session);
          if (saved case Err(failure: final f)) {
            await _logger.captureFailure(f);
            return Err(f);
          }
          await _logger.setUser(
            id: outcome.session.user.id.toString(),
            email: outcome.session.user.email.value,
          );
        }
        return Ok(outcome);
    }
  }
}
