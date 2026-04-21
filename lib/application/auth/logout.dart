import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/auth_repository.dart';
import '../../domain/ports/outbound/biometric_credentials_storage.dart';
import '../../domain/ports/outbound/logger_port.dart';
import '../../domain/ports/outbound/session_storage.dart';
import '../../domain/shared/result.dart';

/// Caso de uso: cerrar sesión.
///
/// Diseño:
/// - Notifica al backend, pero su fallo NO bloquea el logout local.
/// - Borra la sesión local (token, email, id, etc.).
/// - Limpia las credenciales biométricas para evitar reabrir con un usuario
///   diferente sin pasar por login.
/// - Limpia la identidad en el LoggerPort para que los siguientes eventos
///   queden anonimizados.
///
/// Esto sustituye al `catch (_) { }` silencioso en `auth_service.dart:282`.
/// Aquí, si falla la notificación al backend, se loguea como warning pero el
/// logout local sigue adelante.
class Logout {
  final AuthRepository _authRepository;
  final SessionStorage _sessionStorage;
  final BiometricCredentialsStorage _biometricStorage;
  final LoggerPort _logger;

  const Logout({
    required AuthRepository authRepository,
    required SessionStorage sessionStorage,
    required BiometricCredentialsStorage biometricStorage,
    required LoggerPort logger,
  })  : _authRepository = authRepository,
        _sessionStorage = sessionStorage,
        _biometricStorage = biometricStorage,
        _logger = logger;

  Future<Result<void, AppFailure>> call({bool clearBiometric = true}) async {
    // 1. Notificar al backend (best-effort)
    final notify = await _authRepository.notifyLogout();
    if (notify case Err(failure: final f)) {
      // Loguear como warning, pero no abortar el logout local.
      await _logger.log(
        LogLevel.warning,
        'Backend logout notification failed; proceeding with local cleanup',
        extra: {'failure_code': f.code},
      );
    }

    // 2. Borrar sesión local
    final cleared = await _sessionStorage.clear();
    if (cleared case Err(failure: final f)) {
      await _logger.captureFailure(f);
      return Err(f);
    }

    // 3. Borrar credenciales biométricas (opcional)
    if (clearBiometric) {
      final clearedBio = await _biometricStorage.clear();
      if (clearedBio case Err(failure: final f)) {
        // No es crítico — sólo logueamos.
        await _logger.captureFailure(f);
      }
    }

    // 4. Anonimizar Sentry
    await _logger.setUser(id: null, email: null);

    return const Ok(null);
  }
}
