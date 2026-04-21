import '../../entities/session.dart';
import '../../exceptions/app_failure.dart';
import '../../shared/result.dart';

/// Puerto que abstrae la persistencia local de la sesión (token, email, id,
/// premium, expiración). La implementación por defecto compone
/// [PreferencesPort] internamente, pero el dominio sólo ve esto.
abstract interface class SessionStorage {
  Future<Result<Session?, StorageFailure>> read();
  Future<Result<void, StorageFailure>> save(Session session);
  Future<Result<void, StorageFailure>> clear();
}
