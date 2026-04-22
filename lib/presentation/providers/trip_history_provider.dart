import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/trip_record.dart';
import 'di.dart';

/// Notifier que gestiona el estado en memoria de la lista de viajes (historial).
/// Sustituye a la variable `_records` que existía en el antiguo TripHistoryService.
class TripHistoryNotifier extends AsyncNotifier<List<TripRecord>> {
  @override
  Future<List<TripRecord>> build() async {
    return _fetchTrips();
  }

  Future<List<TripRecord>> _fetchTrips() async {
    final fetchTripHistory = ref.watch(fetchTripHistoryProvider);
    final result = await fetchTripHistory();
    
    if (result.isErr) {
      throw result.unwrapErr();
    }
    
    return result.unwrap();
  }

  /// Recarga los datos desde el servidor
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchTrips());
  }

  Future<void> deleteTrip(int serverId) async {
    final deleteUseCase = ref.read(deleteTripProvider);
    final result = await deleteUseCase(serverId);
    if (result.isOk) {
      // Actualizamos estado local optimísticamente (o recargamos todo)
      state = state.whenData((trips) {
        return trips.where((t) => t.serverId != serverId).toList();
      });
    }
  }

  Future<void> clearHistory() async {
    final clearUseCase = ref.read(clearTripHistoryProvider);
    final result = await clearUseCase();
    if (result.isOk) {
      state = const AsyncValue.data([]);
    }
  }
}

final tripHistoryNotifierProvider =
    AsyncNotifierProvider<TripHistoryNotifier, List<TripRecord>>(
        TripHistoryNotifier.new);
