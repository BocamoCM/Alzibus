import '../../entities/favorite_stop.dart';
import '../../exceptions/app_failure.dart';
import '../../shared/result.dart';

/// Puerto de persistencia para las paradas favoritas del usuario.
///
/// La lista se guarda en conjunto — `save` reemplaza todo el listado. El
/// dominio se encarga de añadir/eliminar en memoria antes de persistir
/// (ver `AddFavoriteStop` / `RemoveFavoriteStop`).
///
/// La clave secundaria `widgetStopId` identifica cuál de las favoritas se
/// muestra en el widget del launcher.
abstract interface class FavoriteStopRepository {
  /// Devuelve el listado actual, o vacío si aún no hay datos.
  Future<Result<List<FavoriteStop>, AppFailure>> listAll();

  /// Reemplaza el listado completo.
  Future<Result<void, AppFailure>> save(List<FavoriteStop> stops);

  /// Devuelve el stopId que está configurado como widget (o null).
  Future<Result<int?, AppFailure>> getWidgetStopId();

  /// Marca (o limpia con null) la parada a mostrar en el widget.
  Future<Result<void, AppFailure>> setWidgetStopId(int? stopId);
}
