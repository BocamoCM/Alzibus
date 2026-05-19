import 'dart:math' as math;

import '../models/bus_stop.dart';
import '../models/trip_plan.dart';
import 'stops_service.dart';

/// Motor de planificación de viajes en bus para Alzira.
///
/// Dada una pareja origen-destino (paradas o coordenadas), calcula la mejor
/// ruta disponible usando las 3 líneas locales. Algoritmo:
///
/// 1. **Ruta directa**: si origen y destino comparten una línea, esa es la
///    ruta preferida. Si comparten varias, se elige la que pase por menos
///    paradas intermedias.
/// 2. **Un transbordo**: para cada parada común entre la línea del origen y
///    la línea del destino, se calcula la suma de paradas intermedias + una
///    penalización fija por transbordo (5 min). Se devuelve la combinación
///    más corta.
///
/// El grafo es pequeño (≈57 paradas, 3 líneas) así que un BFS naive sobra.
/// Sin caches sofisticadas: las rutas de cada línea se cargan una vez al
/// inicializar y se mantienen en memoria.
///
/// **No depende del backend** — funciona 100% offline con los assets locales.
class TripPlannerService {
  static const _avgMinPerStop = 2; // tiempo medio bus entre paradas
  static const _walkSpeedMps = 1.1; // 1.1 m/s = 4 km/h (caminata media)
  // Nota: cuando implementemos transbordos que requieren andar entre paradas
  // distintas (no en la misma esquina), añadir _walkConnectionMaxM y
  // _transferPenaltyMin. De momento usamos TransferStep.durationMin=5 fijo.

  final StopsService _stopsService;

  // Cache en memoria. Se cargan en initialize() y no se vuelven a recargar.
  List<BusStop>? _allStops;
  final Map<String, List<BusStop>> _routesByLine = {};

  TripPlannerService(this._stopsService);

  /// Carga paradas y rutas. Llamar una vez al iniciar la app o al abrir el
  /// planificador. Idempotente — si ya está cargado, no hace nada.
  Future<void> initialize() async {
    if (_allStops != null) return;

    _allStops = await _stopsService.loadStops();

    // Cargamos las rutas de cada línea encontrada en las paradas. Esto
    // descubre líneas dinámicamente — si añades L4 mañana, esto la coge sola.
    final allLines = <String>{};
    for (final stop in _allStops!) {
      allLines.addAll(stop.lines);
    }

    for (final lineId in allLines) {
      final rawStops = await _stopsService.loadLineRoute(lineId);
      _routesByLine[lineId] = rawStops
          .map((raw) => BusStop(
                id: raw['id'] as int,
                name: raw['name'] as String,
                lat: (raw['lat'] as num).toDouble(),
                lng: (raw['lng'] as num).toDouble(),
                lines: [lineId], // dentro de la ruta de una línea, solo esa
              ))
          .toList();
    }
  }

  /// Plan principal: encuentra hasta 3 alternativas ordenadas por duración
  /// total. Si no hay ruta posible, lista vacía.
  ///
  /// Pasa [originStopId] y [destinationStopId] como `id` (no por nombre).
  /// Para incluir un tramo a pie inicial/final, pasa además [originCoord] o
  /// [destinationCoord] — si son distintas de las coordenadas de la parada,
  /// se añade un WalkStep al principio/final.
  Future<List<TripPlan>> plan({
    required int originStopId,
    required int destinationStopId,
    ({double lat, double lng})? originCoord,
    ({double lat, double lng})? destinationCoord,
  }) async {
    await initialize();
    if (originStopId == destinationStopId) {
      return [_trivialSameStopPlan(originStopId)];
    }

    final origin = _findStop(originStopId);
    final destination = _findStop(destinationStopId);
    if (origin == null || destination == null) return [];

    final candidates = <TripPlan>[];

    // 1. Rutas directas (sin transbordo).
    for (final line in origin.lines) {
      if (!destination.lines.contains(line)) continue;
      final route = _routesByLine[line];
      if (route == null) continue;

      final direct = _buildDirectPlan(
        line: line,
        route: route,
        origin: origin,
        destination: destination,
        originCoord: originCoord,
        destinationCoord: destinationCoord,
      );
      if (direct != null) candidates.add(direct);
    }

    // 2. Rutas con un transbordo.
    for (final lineA in origin.lines) {
      for (final lineB in destination.lines) {
        if (lineA == lineB) continue; // ya cubierto por directas
        final commonStops = _stopsOnBothLines(lineA, lineB);
        for (final transfer in commonStops) {
          final plan = _buildOneTransferPlan(
            lineA: lineA,
            lineB: lineB,
            origin: origin,
            destination: destination,
            transferStop: transfer,
            originCoord: originCoord,
            destinationCoord: destinationCoord,
          );
          if (plan != null) candidates.add(plan);
        }
      }
    }

    // Ordenamos por duración total asc, después por nº transbordos asc.
    candidates.sort((a, b) {
      final byDur = a.totalDurationMin.compareTo(b.totalDurationMin);
      if (byDur != 0) return byDur;
      return a.transferCount.compareTo(b.transferCount);
    });

    // Devolvemos hasta 3 alternativas únicas (deduplicando por firma de líneas).
    final seen = <String>{};
    final unique = <TripPlan>[];
    for (final c in candidates) {
      final sig = '${c.linesUsed.join(",")}|${c.transferCount}';
      if (seen.add(sig)) {
        unique.add(c);
        if (unique.length >= 3) break;
      }
    }
    return unique;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Construcción de planes
  // ─────────────────────────────────────────────────────────────────────────

  TripPlan? _buildDirectPlan({
    required String line,
    required List<BusStop> route,
    required BusStop origin,
    required BusStop destination,
    ({double lat, double lng})? originCoord,
    ({double lat, double lng})? destinationCoord,
  }) {
    final iFrom = route.indexWhere((s) => s.id == origin.id);
    final iTo = route.indexWhere((s) => s.id == destination.id);
    if (iFrom < 0 || iTo < 0) return null;

    // Para líneas en bucle: si destino está "antes" en el array, asumimos que
    // el bus continúa el bucle y pasa por ahí dando la vuelta. Esto es una
    // simplificación: si la línea NO es circular (es lineal), iTo < iFrom
    // significaría imposible y deberíamos descartar. Para Alzitrans las 3
    // líneas son loops, así que esto funciona. Si en el futuro hay líneas
    // lineales con dirección única, habrá que distinguirlas.
    final stops = _slicePathThroughRoute(route, iFrom, iTo);
    if (stops.length < 2) return null;

    final intermediate = stops.sublist(1, stops.length - 1);
    final busStep = BusStep(
      line: line,
      fromStop: origin,
      toStop: destination,
      intermediateStops: intermediate,
      durationMin: _estimateBusMin(stops.length - 1),
    );

    return _wrapWithWalks(
      busSteps: [busStep],
      transfers: const [],
      walkConnections: const [],
      origin: origin,
      destination: destination,
      originCoord: originCoord,
      destinationCoord: destinationCoord,
    );
  }

  TripPlan? _buildOneTransferPlan({
    required String lineA,
    required String lineB,
    required BusStop origin,
    required BusStop destination,
    required BusStop transferStop,
    ({double lat, double lng})? originCoord,
    ({double lat, double lng})? destinationCoord,
  }) {
    final routeA = _routesByLine[lineA];
    final routeB = _routesByLine[lineB];
    if (routeA == null || routeB == null) return null;

    final iFromA = routeA.indexWhere((s) => s.id == origin.id);
    final iTransferA = routeA.indexWhere((s) => s.id == transferStop.id);
    final iTransferB = routeB.indexWhere((s) => s.id == transferStop.id);
    final iToB = routeB.indexWhere((s) => s.id == destination.id);
    if (iFromA < 0 || iTransferA < 0 || iTransferB < 0 || iToB < 0) return null;

    final pathA = _slicePathThroughRoute(routeA, iFromA, iTransferA);
    final pathB = _slicePathThroughRoute(routeB, iTransferB, iToB);
    if (pathA.length < 2 || pathB.length < 2) return null;

    final busA = BusStep(
      line: lineA,
      fromStop: origin,
      toStop: transferStop,
      intermediateStops: pathA.sublist(1, pathA.length - 1),
      durationMin: _estimateBusMin(pathA.length - 1),
    );
    final transfer = TransferStep(
      fromLine: lineA,
      toLine: lineB,
      atStop: transferStop,
    );
    final busB = BusStep(
      line: lineB,
      fromStop: transferStop,
      toStop: destination,
      intermediateStops: pathB.sublist(1, pathB.length - 1),
      durationMin: _estimateBusMin(pathB.length - 1),
    );

    return _wrapWithWalks(
      busSteps: [busA, busB],
      transfers: [transfer],
      walkConnections: const [],
      origin: origin,
      destination: destination,
      originCoord: originCoord,
      destinationCoord: destinationCoord,
    );
  }

  /// Mete WalkSteps al principio (si hay [originCoord]) y al final (si hay
  /// [destinationCoord]), monta el TripPlan con totales, y entrelaza los
  /// transbordos entre los BusSteps.
  TripPlan _wrapWithWalks({
    required List<BusStep> busSteps,
    required List<TransferStep> transfers,
    required List<WalkStep> walkConnections,
    required BusStop origin,
    required BusStop destination,
    ({double lat, double lng})? originCoord,
    ({double lat, double lng})? destinationCoord,
  }) {
    final steps = <TripStep>[];

    // Walk inicial si la ubicación no es la parada origen.
    if (originCoord != null) {
      final distM = _haversineM(
        originCoord.lat, originCoord.lng, origin.lat, origin.lng);
      if (distM > 30) {
        steps.add(WalkStep(
          fromLabel: 'Tu ubicación',
          toLabel: origin.name,
          distanceM: distM.round(),
          durationMin: _estimateWalkMin(distM),
        ));
      }
    }

    // Entrelazamos buses y transbordos.
    for (var i = 0; i < busSteps.length; i++) {
      steps.add(busSteps[i]);
      if (i < transfers.length) steps.add(transfers[i]);
    }

    // Walk final si el destino no es la parada de bajada.
    if (destinationCoord != null) {
      final distM = _haversineM(
        destination.lat, destination.lng, destinationCoord.lat, destinationCoord.lng);
      if (distM > 30) {
        steps.add(WalkStep(
          fromLabel: destination.name,
          toLabel: 'Tu destino',
          distanceM: distM.round(),
          durationMin: _estimateWalkMin(distM),
        ));
      }
    }

    final totalMin = steps.fold<int>(0, (sum, s) => sum + s.durationMin);
    final walkM = steps
        .whereType<WalkStep>()
        .fold<int>(0, (sum, s) => sum + s.distanceM);

    return TripPlan(
      steps: steps,
      totalDurationMin: totalMin,
      transferCount: transfers.length,
      walkingDistanceM: walkM,
    );
  }

  TripPlan _trivialSameStopPlan(int stopId) {
    return TripPlan(
      steps: [
        WalkStep(
          fromLabel: 'Tu ubicación',
          toLabel: 'Tu destino',
          distanceM: 0,
          durationMin: 0,
        ),
      ],
      totalDurationMin: 0,
      transferCount: 0,
      walkingDistanceM: 0,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  BusStop? _findStop(int id) {
    final all = _allStops;
    if (all == null) return null;
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Devuelve la secuencia de paradas de [route] entre los índices [from] y
  /// [to] respetando el orden del array. Si [to] < [from], se asume que es
  /// una línea en bucle y se da la vuelta.
  List<BusStop> _slicePathThroughRoute(List<BusStop> route, int from, int to) {
    if (from == to) return [route[from]];
    if (from < to) return route.sublist(from, to + 1);
    // Loop: from -> end, 0 -> to
    return [...route.sublist(from), ...route.sublist(0, to + 1)];
  }

  /// Paradas (objetos completos del routeA) que también están en lineB.
  List<BusStop> _stopsOnBothLines(String lineA, String lineB) {
    final routeA = _routesByLine[lineA];
    final routeB = _routesByLine[lineB];
    if (routeA == null || routeB == null) return [];
    final idsInB = routeB.map((s) => s.id).toSet();
    return routeA.where((s) => idsInB.contains(s.id)).toList();
  }

  int _estimateBusMin(int hops) =>
      math.max(1, hops * _avgMinPerStop);

  int _estimateWalkMin(double distanceM) =>
      math.max(1, (distanceM / _walkSpeedMps / 60).round());

  /// Haversine en metros (sin libs externas, usamos math.dart estándar).
  double _haversineM(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _toRad(double deg) => deg * math.pi / 180;
}
