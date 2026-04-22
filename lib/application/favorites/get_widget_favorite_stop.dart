import '../../domain/entities/favorite_stop.dart';
import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/favorite_stop_repository.dart';
import '../../domain/shared/result.dart';

/// Caso de uso: devolver la parada favorita actualmente asignada al widget.
///
/// Si no hay una asignación explícita, se devuelve la primera favorita. Si la
/// lista está vacía, se devuelve `null`.
class GetWidgetFavoriteStop {
  final FavoriteStopRepository _repository;

  const GetWidgetFavoriteStop({required FavoriteStopRepository repository})
      : _repository = repository;

  Future<Result<FavoriteStop?, AppFailure>> call() async {
    final idResult = await _repository.getWidgetStopId();
    if (idResult.isErr) return Err(idResult.unwrapErr());
    final stopId = idResult.unwrap();

    final listResult = await _repository.listAll();
    if (listResult.isErr) return Err(listResult.unwrapErr());
    final favorites = listResult.unwrap();

    if (favorites.isEmpty) return const Ok(null);

    if (stopId == null) return Ok(favorites.first);

    try {
      return Ok(favorites.firstWhere((f) => f.stopId == stopId));
    } on StateError {
      return Ok(favorites.first);
    }
  }
}
