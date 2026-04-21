import '../../exceptions/app_failure.dart';

/// Niveles de log soportados.
enum LogLevel { debug, info, warning, error }

/// Puerto de observabilidad. La implementación por defecto envía a Sentry,
/// pero el dominio sólo conoce esta interfaz.
///
/// Reglas de uso:
/// - Capturar TODO `AppFailure` que se devuelva desde un caso de uso vía
///   un decorador (`LoggingAuthRepository`, etc.) — no esparcir llamadas.
/// - `breadcrumb()` para eventos de navegación o acciones del usuario.
/// - `setUser()` se invoca al hacer login y al hacer logout (con `null`).
abstract interface class LoggerPort {
  /// Captura un fallo de dominio (con causa y stack si están).
  Future<void> captureFailure(AppFailure failure);

  /// Captura una excepción cualquiera con stack opcional.
  Future<void> captureException(Object error, [StackTrace? stackTrace]);

  /// Mensaje libre con un nivel asociado.
  Future<void> log(LogLevel level, String message, {Map<String, Object?>? extra});

  /// Migaja para reconstruir lo que pasó antes de un crash.
  void breadcrumb(String message, {String? category, Map<String, Object?>? data});

  /// Asocia el log al usuario actual. `null` para anonimizar (logout).
  Future<void> setUser({String? id, String? email});
}
