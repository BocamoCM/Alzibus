import '../../domain/entities/session.dart';
import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/auth_repository.dart';
import '../../domain/ports/outbound/logger_port.dart';
import '../../domain/ports/outbound/session_storage.dart';
import '../../domain/shared/result.dart';
import '../../domain/value_objects/email.dart';

/// Caso de uso: verifica el OTP de login (2FA) y, si es válido, guarda la
/// sesión devuelta por el backend.
class VerifyLoginOtp {
  final AuthRepository _authRepository;
  final SessionStorage _sessionStorage;
  final LoggerPort _logger;

  const VerifyLoginOtp({
    required AuthRepository authRepository,
    required SessionStorage sessionStorage,
    required LoggerPort logger,
  })  : _authRepository = authRepository,
        _sessionStorage = sessionStorage,
        _logger = logger;

  Future<Result<Session, AppFailure>> call({
    required String rawEmail,
    required String code,
  }) async {
    final emailResult = Email.tryParse(rawEmail);
    if (emailResult case Err(failure: final f)) return Err(f);
    if (code.trim().isEmpty) {
      return const Err(ValidationFailure(fieldErrors: {'code': 'empty'}));
    }
    final email = emailResult.unwrap();

    final result = await _authRepository.verifyLoginOtp(email, code.trim());
    switch (result) {
      case Err(failure: final f):
        await _logger.captureFailure(f);
        return Err(f);
      case Ok(value: final session):
        final saved = await _sessionStorage.save(session);
        if (saved case Err(failure: final f)) {
          await _logger.captureFailure(f);
          return Err(f);
        }
        await _logger.setUser(
          id: session.user.id.toString(),
          email: session.user.email.value,
        );
        return Ok(session);
    }
  }
}
