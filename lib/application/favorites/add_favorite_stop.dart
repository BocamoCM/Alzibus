import '../../domain/entities/favorite_stop.dart';
import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/favorite_stop_repository.dart';
import '../../domain/shared/result.dart';

/// Caso de uso: añadir una parada a favoritos.
///
/// Reglas de negocio:
/// - No se permiten duplicados por `stopId`. Se devuelve
///   [FavoriteAlreadyExistsFailure] si ya existe.
/// - Si era la primera favorita del usuario, se asigna automáticamente como
///   parada del widget.
class AddFavoriteStop {
  final FavoriteStopRepository _repository;

  const AddFavoriteStop({required FavoriteStopRepository repository})
      : _repository = repository;

  Future<Result<void, AppFailure>> call(FavoriteStop stop) async {
    final listResult = await _repository.listAll();
    if (listResult.isErr) return Err(listResult.unwrapErr());
    final current = listResult.unwrap();

    if (current.any((f) => f.stopId == stop.stopId)) {
      return const Err(FavoriteAlreadyExistsFailure());
    }

    final updated = [...current, stop];
    final saveResult = await _repository.save(updated);
    if (saveResult.isErr) return Err(saveResult.unwrapErr());

    // Si era la primera, la designamos como widget.
    if (current.isEmpty) {
      final widgetResult =
          await _repository.setWidgetStopId(stop.stopId);
      if (widgetResult.isErr) return Err(widgetResult.unwrapErr());
    }

    return const Ok(null);
  }
}
