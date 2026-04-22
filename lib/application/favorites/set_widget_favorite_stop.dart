import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/favorite_stop_repository.dart';
import '../../domain/shared/result.dart';

/// Caso de uso: fijar una parada concreta como la del widget del launcher.
///
/// Valida que la parada esté en favoritos antes de persistir la asignación.
class SetWidgetFavoriteStop {
  final FavoriteStopRepository _repository;

  const SetWidgetFavoriteStop({required FavoriteStopRepository repository})
      : _repository = repository;

  Future<Result<void, AppFailure>> call(int stopId) async {
    final listResult = await _repository.listAll();
    if (listResult.isErr) return Err(listResult.unwrapErr());
    final favorites = listResult.unwrap();

    if (!favorites.any((f) => f.stopId == stopId)) {
      return const Err(FavoriteNotFoundFailure());
    }

    return _repository.setWidgetStopId(stopId);
  }
}
