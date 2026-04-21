import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/biometric_credentials_storage.dart';
import '../../domain/ports/outbound/logger_port.dart';
import '../../domain/shared/result.dart';
import '../../domain/value_objects/email.dart';
import '../../domain/value_objects/password.dart';

/// Caso de uso: persiste las credenciales del usuario para habilitar el login
/// biométrico en siguientes sesiones.
///
/// Se usa después de un login con password exitoso (o tras OTP), cuando el
/// usuario confirma que quiere usar huella/face en el futuro.
class EnableBiometrics {
  final BiometricCredentialsStorage _storage;
  final LoggerPort _logger;

  const EnableBiometrics({
    required BiometricCredentialsStorage storage,
    required LoggerPort logger,
  })  : _storage = storage,
        _logger = logger;

  Future<Result<void, AppFailure>> call({
    required String rawEmail,
    required String rawPassword,
  }) async {
    final emailResult = Email.tryParse(rawEmail);
    final passwordResult = Password.tryParse(rawPassword);
    if (emailResult case Err(failure: final f)) return Err(f);
    if (passwordResult case Err(failure: final f)) return Err(f);

    final saved = await _storage.save(BiometricCredentials(
      email: emailResult.unwrap(),
      password: passwordResult.unwrap(),
    ));
    if (saved case Err(failure: final f)) {
      await _logger.captureFailure(f);
      return Err(f);
    }
    return const Ok(null);
  }
}
