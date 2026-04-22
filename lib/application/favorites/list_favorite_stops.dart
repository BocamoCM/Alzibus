import '../../domain/entities/favorite_stop.dart';
import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/favorite_stop_repository.dart';
import '../../domain/shared/result.dart';

/// Caso de uso: devolver todas las paradas favoritas.
class ListFavoriteStops {
  final FavoriteStopRepository _repository;

  const ListFavoriteStops({required FavoriteStopRepository repository})
      : _repository = repository;

  Future<Result<List<FavoriteStop>, AppFailure>> call() =>
      _repository.listAll();
}
