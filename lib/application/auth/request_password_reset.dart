import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/auth_repository.dart';
import '../../domain/ports/outbound/logger_port.dart';
import '../../domain/shared/result.dart';
import '../../domain/value_objects/email.dart';

/// Caso de uso: solicitar código de recuperación de contraseña.
class RequestPasswordReset {
  final AuthRepository _authRepository;
  final LoggerPort _logger;

  const RequestPasswordReset({
    required AuthRepository authRepository,
    required LoggerPort logger,
  })  : _authRepository = authRepository,
        _logger = logger;

  Future<Result<void, AppFailure>> call({required String rawEmail}) async {
    final emailResult = Email.tryParse(rawEmail);
    if (emailResult case Err(failure: final f)) return Err(f);

    final result = await _authRepository.requestPasswordReset(emailResult.unwrap());
    if (result case Err(failure: final f)) {
      await _logger.captureFailure(f);
      return Err(f);
    }

    return const Ok(null);
  }
}
