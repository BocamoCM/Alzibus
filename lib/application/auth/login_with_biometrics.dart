import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/biometric_authenticator.dart';
import '../../domain/ports/outbound/biometric_credentials_storage.dart';
import '../../domain/shared/result.dart';
import 'login_with_password.dart';

/// Resultado del login biométrico.
sealed class BiometricLoginOutcome {
  const BiometricLoginOutcome();
}

/// La biometría no está habilitada o no hay credenciales guardadas.
class BiometricNotConfigured extends BiometricLoginOutcome {
  const BiometricNotConfigured();
}

/// El usuario canceló el diálogo o la huella no coincidió.
class BiometricCancelled extends BiometricLoginOutcome {
  const BiometricCancelled();
}

/// Login completado tras biometría.
class BiometricSucceeded extends BiometricLoginOutcome {
  const BiometricSucceeded();
}

/// Caso de uso: login automático con huella/face. Reusa [LoginWithPassword]
/// internamente — el servidor salta el OTP cuando se pasa `biometric: true`.
class LoginWithBiometrics {
  final BiometricCredentialsStorage _credentialsStorage;
  final BiometricAuthenticator _authenticator;
  final LoginWithPassword _loginWithPassword;

  const LoginWithBiometrics({
    required BiometricCredentialsStorage credentialsStorage,
    required BiometricAuthenticator authenticator,
    required LoginWithPassword loginWithPassword,
  })  : _credentialsStorage = credentialsStorage,
        _authenticator = authenticator,
        _loginWithPassword = loginWithPassword;

  Future<Result<BiometricLoginOutcome, AppFailure>> call({
    required String reason,
  }) async {
    if (!await _credentialsStorage.isEnabled()) {
      return const Ok(BiometricNotConfigured());
    }

    final auth = await _authenticator.authenticate(reason: reason);
    if (auth is Err<bool, BiometricUnavailableFailure>) {
      return Err(auth.failure);
    }
    if (!auth.unwrap()) {
      return const Ok(BiometricCancelled());
    }

    final credsResult = await _credentialsStorage.read();
    switch (credsResult) {
      case Err(failure: final f):
        return Err(f);
      case Ok(value: final creds):
        if (creds == null) return const Ok(BiometricNotConfigured());

        final loginResult = await _loginWithPassword(
          rawEmail: creds.email.value,
          rawPassword: creds.password.value,
          biometric: true,
        );
        switch (loginResult) {
          case Err(failure: final f):
            return Err(f);
          case Ok():
            return const Ok(BiometricSucceeded());
        }
    }
  }
}
