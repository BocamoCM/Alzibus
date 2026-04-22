import '../../domain/entities/favorite_stop.dart';
import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/favorite_widget_gateway.dart';
import '../../domain/ports/outbound/logger_port.dart';
import '../../domain/ports/outbound/stop_arrival_fetcher.dart';
import '../../domain/shared/result.dart';
import 'get_widget_favorite_stop.dart';

/// Caso de uso: refrescar el widget del launcher con el próximo bus de la
/// parada favorita actual.
///
/// Orquesta tres cosas:
/// 1. `GetWidgetFavoriteStop` para saber qué parada pintar (o limpiar).
/// 2. `StopArrivalFetcher` para traer el tiempo del próximo autobús.
/// 3. `FavoriteWidgetGateway` para publicar el snapshot en el widget.
///
/// Si falla el fetch de arrivals se loguea como warning pero se sigue
/// pintando el widget con "Sin datos" — así el widget siempre muestra al
/// menos el nombre de la parada.
class SyncFavoriteWidget {
  final GetWidgetFavoriteStop _getWidgetFavorite;
  final StopArrivalFetcher _arrivalFetcher;
  final FavoriteWidgetGateway _widgetGateway;
  final LoggerPort _logger;

  const SyncFavoriteWidget({
    required GetWidgetFavoriteStop getWidgetFavorite,
    required StopArrivalFetcher arrivalFetcher,
    required FavoriteWidgetGateway widgetGateway,
    required LoggerPort logger,
  })  : _getWidgetFavorite = getWidgetFavorite,
        _arrivalFetcher = arrivalFetcher,
        _widgetGateway = widgetGateway,
        _logger = logger;

  Future<Result<void, AppFailure>> call() async {
    final favResult = await _getWidgetFavorite();
    if (favResult.isErr) return Err(favResult.unwrapErr());
    final stop = favResult.unwrap();

    if (stop == null) {
      return _widgetGateway.render(null);
    }

    final snapshot = await _buildSnapshot(stop);
    return _widgetGateway.render(snapshot);
  }

  Future<FavoriteWidgetSnapshot> _buildSnapshot(FavoriteStop stop) async {
    String lineDestination = 'Sin datos';
    String arrivalTime = '--';

    final arrivalResult = await _arrivalFetcher.fetchNextArrival(stop.stopId);
    if (arrivalResult.isOk) {
      final arrival = arrivalResult.unwrap();
      if (arrival != null) {
        lineDestination = '${arrival.line} → ${arrival.destination}';
        arrivalTime = arrival.displayTime;
      }
    } else {
      await _logger.captureFailure(arrivalResult.unwrapErr());
    }

    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return FavoriteWidgetSnapshot(
      stopName: stop.stopName,
      lineDestination: lineDestination,
      arrivalTime: arrivalTime,
      lastUpdate: timeStr,
    );
  }
}
