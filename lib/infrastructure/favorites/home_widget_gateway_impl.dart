import 'package:home_widget/home_widget.dart';

import '../../domain/entities/favorite_stop.dart';
import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/favorite_widget_gateway.dart';
import '../../domain/shared/result.dart';

/// Adaptador de [FavoriteWidgetGateway] sobre el plugin `home_widget`.
class HomeWidgetGatewayImpl implements FavoriteWidgetGateway {
  static const String _androidWidgetName = 'BusWidgetProvider';

  const HomeWidgetGatewayImpl();

  @override
  Future<Result<void, AppFailure>> render(
      FavoriteWidgetSnapshot? snapshot) async {
    try {
      final data = snapshot ?? FavoriteWidgetSnapshot.empty();
      await HomeWidget.saveWidgetData('widget_stop_name', data.stopName);
      await HomeWidget.saveWidgetData(
          'widget_line_destination', data.lineDestination);
      await HomeWidget.saveWidgetData(
          'widget_arrival_time', data.arrivalTime);
      await HomeWidget.saveWidgetData(
          'widget_last_update', data.lastUpdate);
      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        androidName: _androidWidgetName,
      );
      return const Ok(null);
    } catch (e, s) {
      return Err(FavoriteWidgetSyncFailure(cause: e, stackTrace: s));
    }
  }
}
