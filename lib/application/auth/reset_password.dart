import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/auth_repository.dart';
import '../../domain/ports/outbound/logger_port.dart';
import '../../domain/shared/result.dart';
import '../../domain/value_objects/email.dart';
import '../../domain/value_objects/password.dart';

/// Caso de uso: restablecer contraseña con código OTP.
class ResetPassword {
  final AuthRepository _authRepository;
  final LoggerPort _logger;

  const ResetPassword({
    required AuthRepository authRepository,
    required LoggerPort logger,
  })  : _authRepository = authRepository,
        _logger = logger;

  Future<Result<void, AppFailure>> call({
    required String rawEmail,
    required String code,
    required String rawNewPassword,
  }) async {
    final emailResult = Email.tryParse(rawEmail);
    final passwordResult = Password.tryParse(rawNewPassword);
    if (emailResult case Err(failure: final f)) return Err(f);
    if (passwordResult case Err(failure: final f)) return Err(f);
    if (code.trim().isEmpty) {
      return const Err(ValidationFailure(fieldErrors: {'code': 'empty'}));
    }

    final result = await _authRepository.resetPassword(
      email: emailResult.unwrap(),
      code: code.trim(),
      newPassword: passwordResult.unwrap(),
    );
    if (result case Err(failure: final f)) {
      await _logger.captureFailure(f);
      return Err(f);
    }

    return const Ok(null);
  }
}
