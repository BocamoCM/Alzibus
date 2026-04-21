import '../../exceptions/app_failure.dart';
import '../../shared/result.dart';
import '../../value_objects/email.dart';
import '../../value_objects/password.dart';

/// Credenciales guardadas para reabrir la app con biometría.
class BiometricCredentials {
  final Email email;
  final Password password;
  const BiometricCredentials({required this.email, required this.password});
}

/// Puerto: persistencia segura de las credenciales que respaldan el login
/// biométrico. La implementación usa `flutter_secure_storage`.
abstract interface class BiometricCredentialsStorage {
  Future<Result<BiometricCredentials?, StorageFailure>> read();
  Future<Result<void, StorageFailure>> save(BiometricCredentials credentials);
  Future<Result<void, StorageFailure>> clear();
  Future<bool> isEnabled();
}
