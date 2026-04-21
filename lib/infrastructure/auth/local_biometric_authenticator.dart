import 'package:local_auth/local_auth.dart';

import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/biometric_authenticator.dart';
import '../../domain/shared/result.dart';

/// Adaptador de [BiometricAuthenticator] basado en `local_auth`.
class LocalBiometricAuthenticator implements BiometricAuthenticator {
  final LocalAuthentication _auth;

  LocalBiometricAuthenticator([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Result<bool, BiometricUnavailableFailure>> authenticate({
    required String reason,
  }) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return Ok(ok);
    } catch (e, s) {
      return Err(BiometricUnavailableFailure(cause: e, stackTrace: s));
    }
  }
}
