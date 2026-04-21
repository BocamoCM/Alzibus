import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth/enable_biometrics.dart';
import '../../application/auth/delete_account.dart';
import '../../application/auth/login_with_biometrics.dart';
import '../../application/auth/login_with_password.dart';
import '../../application/auth/logout.dart';
import '../../application/auth/request_password_reset.dart';
import '../../application/auth/register_user.dart';
import '../../application/auth/reset_password.dart';
import '../../application/auth/verify_login_otp.dart';
import '../../core/network/api_client.dart';
import '../../domain/ports/outbound/auth_repository.dart';
import '../../domain/ports/outbound/biometric_authenticator.dart';
import '../../domain/ports/outbound/biometric_credentials_storage.dart';
import '../../domain/ports/outbound/http_port.dart';
import '../../domain/ports/outbound/logger_port.dart';
import '../../domain/ports/outbound/preferences_port.dart';
import '../../domain/ports/outbound/secrets_port.dart';
import '../../domain/ports/outbound/session_storage.dart';
import '../../infrastructure/auth/http_auth_repository.dart';
import '../../infrastructure/auth/local_biometric_authenticator.dart';
import '../../infrastructure/network/dio_http_adapter.dart';
import '../../infrastructure/observability/sentry_logger.dart';
import '../../infrastructure/storage/biometric_credentials_storage_impl.dart';
import '../../infrastructure/storage/secure_storage_adapter.dart';
import '../../infrastructure/storage/session_storage_impl.dart';
import '../../infrastructure/storage/shared_prefs_adapter.dart';
import '../../providers/high_visibility_provider.dart' show sharedPreferencesProvider;

/// ╔════════════════════════════════════════════════════════════════════════╗
/// ║  CABLEADO HEXAGONAL — DEPENDENCY INJECTION                             ║
/// ╠════════════════════════════════════════════════════════════════════════╣
/// ║  Cada `Provider<TPort>` expone un PUERTO del dominio. La instancia     ║
/// ║  concreta (adaptador) se conecta aquí. En tests basta con sobrescribir ║
/// ║  el provider con una implementación fake/mock para aislar el dominio   ║
/// ║  de Flutter, Dio, Sentry, plugins nativos, etc.                        ║
/// ╚════════════════════════════════════════════════════════════════════════╝

// ───────── Infraestructura compartida ─────────

/// Instancia de Dio reutilizada del `ApiClient` legacy. Cuando todo esté
/// migrado podemos crear una Dio dedicada y deprecar `ApiClient`.
final dioProvider = Provider<Dio>((_) => ApiClient().dio);

final preferencesPortProvider = Provider<PreferencesPort>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SharedPrefsAdapter(prefs);
});

final secretsPortProvider = Provider<SecretsPort>(
  (_) => const SecureStorageAdapter(),
);

final loggerPortProvider = Provider<LoggerPort>(
  (_) => const SentryLogger(),
);

final httpPortProvider = Provider<HttpPort>(
  (ref) => DioHttpAdapter(ref.watch(dioProvider)),
);

// ───────── Auth: storages ─────────

final sessionStorageProvider = Provider<SessionStorage>(
  (ref) => SessionStorageImpl(ref.watch(preferencesPortProvider)),
);

final biometricCredentialsStorageProvider =
    Provider<BiometricCredentialsStorage>(
  (ref) => BiometricCredentialsStorageImpl(ref.watch(secretsPortProvider)),
);

final biometricAuthenticatorProvider = Provider<BiometricAuthenticator>(
  (_) => LocalBiometricAuthenticator(),
);

// ───────── Auth: repositorio ─────────

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => HttpAuthRepository(ref.watch(httpPortProvider)),
);

// ───────── Auth: casos de uso ─────────

final loginWithPasswordProvider = Provider<LoginWithPassword>(
  (ref) => LoginWithPassword(
    authRepository: ref.watch(authRepositoryProvider),
    sessionStorage: ref.watch(sessionStorageProvider),
    logger: ref.watch(loggerPortProvider),
  ),
);

final verifyLoginOtpProvider = Provider<VerifyLoginOtp>(
  (ref) => VerifyLoginOtp(
    authRepository: ref.watch(authRepositoryProvider),
    sessionStorage: ref.watch(sessionStorageProvider),
    logger: ref.watch(loggerPortProvider),
  ),
);

final registerUserProvider = Provider<RegisterUser>(
  (ref) => RegisterUser(
    authRepository: ref.watch(authRepositoryProvider),
    logger: ref.watch(loggerPortProvider),
  ),
);

final logoutProvider = Provider<Logout>(
  (ref) => Logout(
    authRepository: ref.watch(authRepositoryProvider),
    sessionStorage: ref.watch(sessionStorageProvider),
    biometricStorage: ref.watch(biometricCredentialsStorageProvider),
    logger: ref.watch(loggerPortProvider),
  ),
);

final loginWithBiometricsProvider = Provider<LoginWithBiometrics>(
  (ref) => LoginWithBiometrics(
    credentialsStorage: ref.watch(biometricCredentialsStorageProvider),
    authenticator: ref.watch(biometricAuthenticatorProvider),
    loginWithPassword: ref.watch(loginWithPasswordProvider),
  ),
);

final enableBiometricsProvider = Provider<EnableBiometrics>(
  (ref) => EnableBiometrics(
    storage: ref.watch(biometricCredentialsStorageProvider),
    logger: ref.watch(loggerPortProvider),
  ),
);

final requestPasswordResetProvider = Provider<RequestPasswordReset>(
  (ref) => RequestPasswordReset(
    authRepository: ref.watch(authRepositoryProvider),
    logger: ref.watch(loggerPortProvider),
  ),
);

final resetPasswordProvider = Provider<ResetPassword>(
  (ref) => ResetPassword(
    authRepository: ref.watch(authRepositoryProvider),
    logger: ref.watch(loggerPortProvider),
  ),
);

final deleteAccountProvider = Provider<DeleteAccount>(
  (ref) => DeleteAccount(
    authRepository: ref.watch(authRepositoryProvider),
    sessionStorage: ref.watch(sessionStorageProvider),
    biometricStorage: ref.watch(biometricCredentialsStorageProvider),
    logger: ref.watch(loggerPortProvider),
  ),
);

// ───────── Auth: estado transitorio UI ─────────

/// Credenciales recién introducidas por el usuario en la pantalla de login que
/// pueden necesitarse en la siguiente pantalla (por ejemplo, para ofrecer
/// activar la biometría tras completar el OTP).
///
/// Se limpia explícitamente cuando el flujo termina (éxito, rechazo o
/// navegación a otra pantalla).
class PendingLoginCredentials {
  final String email;
  final String password;
  const PendingLoginCredentials({required this.email, required this.password});
}

class PendingLoginCredentialsNotifier extends Notifier<PendingLoginCredentials?> {
  @override
  PendingLoginCredentials? build() => null;

  void update(PendingLoginCredentials? state) {
    this.state = state;
  }
}

final pendingLoginCredentialsProvider =
    NotifierProvider<PendingLoginCredentialsNotifier, PendingLoginCredentials?>(
        PendingLoginCredentialsNotifier.new);
