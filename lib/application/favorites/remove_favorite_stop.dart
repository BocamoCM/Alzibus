import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/favorite_stop_repository.dart';
import '../../domain/shared/result.dart';

/// Caso de uso: quitar una parada de favoritos.
///
/// Reglas de negocio:
/// - Si la parada eliminada era la del widget, se reasigna automáticamente a
///   la primera que quede. Si ya no quedan favoritas, se limpia el widget.
class RemoveFavoriteStop {
  final FavoriteStopRepository _repository;

  const RemoveFavoriteStop({required FavoriteStopRepository repository})
      : _repository = repository;

  Future<Result<void, AppFailure>> call(int stopId) async {
    final listResult = await _repository.listAll();
    if (listResult.isErr) return Err(listResult.unwrapErr());
    final current = listResult.unwrap();

    if (!current.any((f) => f.stopId == stopId)) {
      return const Err(FavoriteNotFoundFailure());
    }

    final updated = current.where((f) => f.stopId != stopId).toList();
    final saveResult = await _repository.save(updated);
    if (saveResult.isErr) return Err(saveResult.unwrapErr());

    final widgetIdResult = await _repository.getWidgetStopId();
    if (widgetIdResult.isErr) return Err(widgetIdResult.unwrapErr());

    if (widgetIdResult.unwrap() == stopId) {
      final nextWidgetId = updated.isNotEmpty ? updated.first.stopId : null;
      final setResult = await _repository.setWidgetStopId(nextWidgetId);
      if (setResult.isErr) return Err(setResult.unwrapErr());
    }

    return const Ok(null);
  }
}
