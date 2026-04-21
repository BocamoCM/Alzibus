import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/auth_repository.dart';
import '../../domain/ports/outbound/logger_port.dart';
import '../../domain/shared/result.dart';
import '../../domain/value_objects/email.dart';
import '../../domain/value_objects/password.dart';

/// Caso de uso: registrar un nuevo usuario. Tras esto, el flujo continúa con
/// `VerifyEmailUseCase` cuando el usuario introduce el código del correo.
class RegisterUser {
  final AuthRepository _authRepository;
  final LoggerPort _logger;

  const RegisterUser({
    required AuthRepository authRepository,
    required LoggerPort logger,
  })  : _authRepository = authRepository,
        _logger = logger;

  Future<Result<void, AppFailure>> call({
    required String rawEmail,
    required String rawPassword,
  }) async {
    final emailResult = Email.tryParse(rawEmail);
    final passwordResult = Password.tryParse(rawPassword);
    if (emailResult case Err(failure: final f)) return Err(f);
    if (passwordResult case Err(failure: final f)) return Err(f);

    final result = await _authRepository.register(
      emailResult.unwrap(),
      passwordResult.unwrap(),
    );
    if (result case Err(failure: final f)) {
      await _logger.captureFailure(f);
      return Err(f);
    }
    return const Ok(null);
  }
}
