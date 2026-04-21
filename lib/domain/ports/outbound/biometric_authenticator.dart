import '../../exceptions/app_failure.dart';
import '../../shared/result.dart';

/// Puerto que abstrae el plugin de autenticación biométrica del dispositivo.
abstract interface class BiometricAuthenticator {
  /// `true` si el hardware soporta biometría y hay alguna huella registrada.
  Future<bool> isAvailable();

  /// Lanza el diálogo nativo. Devuelve `Ok(true)` si el usuario verificó,
  /// `Ok(false)` si lo canceló sin error, o `Err(BiometricUnavailableFailure)`
  /// si hubo un fallo del plugin.
  Future<Result<bool, BiometricUnavailableFailure>> authenticate({
    required String reason,
  });
}
