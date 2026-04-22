import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/favorite_stop_repository.dart';
import '../../domain/shared/result.dart';

/// Caso de uso: consultar si una parada concreta ya está en favoritos.
class IsFavoriteStop {
  final FavoriteStopRepository _repository;

  const IsFavoriteStop({required FavoriteStopRepository repository})
      : _repository = repository;

  Future<Result<bool, AppFailure>> call(int stopId) async {
    final result = await _repository.listAll();
    if (result.isErr) return Err(result.unwrapErr());
    final favorites = result.unwrap();
    return Ok(favorites.any((f) => f.stopId == stopId));
  }
}
