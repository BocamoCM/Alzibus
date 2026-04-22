import '../../entities/favorite_stop.dart';
import '../../exceptions/app_failure.dart';
import '../../shared/result.dart';

/// Puerto de salida para pintar información en el widget del launcher.
///
/// Encapsula `HomeWidget` del plugin `home_widget` para que la capa de
/// aplicación/dominio no dependa de Flutter/Android directamente.
abstract interface class FavoriteWidgetGateway {
  /// Publica un snapshot de datos en el widget. Si `snapshot` es null, el
  /// adaptador limpiará el widget con los valores por defecto.
  Future<Result<void, AppFailure>> render(FavoriteWidgetSnapshot? snapshot);
}
