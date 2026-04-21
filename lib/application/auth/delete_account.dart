import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/auth_repository.dart';
import '../../domain/ports/outbound/logger_port.dart';
import '../../domain/ports/outbound/session_storage.dart';
import '../../domain/ports/outbound/biometric_credentials_storage.dart';
import '../../domain/shared/result.dart';

/// Caso de uso: eliminar cuenta permanentemente y limpiar sesión local.
class DeleteAccount {
  final AuthRepository _authRepository;
  final SessionStorage _sessionStorage;
  final BiometricCredentialsStorage _biometricStorage;
  final LoggerPort _logger;

  const DeleteAccount({
    required AuthRepository authRepository,
    required SessionStorage sessionStorage,
    required BiometricCredentialsStorage biometricStorage,
    required LoggerPort logger,
  })  : _authRepository = authRepository,
        _sessionStorage = sessionStorage,
        _biometricStorage = biometricStorage,
        _logger = logger;

  Future<Result<void, AppFailure>> call() async {
    final deleted = await _authRepository.deleteAccount();
    if (deleted case Err(failure: final f)) {
      await _logger.captureFailure(f);
      return Err(f);
    }

    final cleared = await _sessionStorage.clear();
    if (cleared case Err(failure: final f)) {
      await _logger.captureFailure(f);
      return Err(f);
    }

    final clearedBio = await _biometricStorage.clear();
    if (clearedBio case Err(failure: final f)) {
      await _logger.captureFailure(f);
    }

    await _logger.setUser(id: null, email: null);
    return const Ok(null);
  }
}
