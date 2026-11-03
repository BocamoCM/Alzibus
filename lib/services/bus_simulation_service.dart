import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'bus_times_service.dart';
import 'gps_track_service.dart';
import 'route_geometry.dart';

/// Bus simulado a partir de los tiempos de llegada del operador.
///
/// La posición real es [distance] (metros sobre el recorrido de su línea);
/// el resto de campos se derivan de ella para la interfaz.
class SimulatedBus {
  final String lineId;
  final String busId;
  LatLng currentPosition;
  double heading;
  double speed;
  int currentStopIndex;
  int nextStopIndex;
  double progress;
  bool isAtStop;
  DateTime? departureTime;
  int? lastKnownMinutes;
  int? trackingStopId;
  int? trackingStopIndex;
  List<LatLng>? gpsTrack;
  int trackFromIndex;
  int trackToIndex;
  DateTime? lastApiUpdate;
  double targetProgress;

  /// Metros recorridos desde el principio del recorrido de la línea.
  double distance;

  /// Velocidad actual en m/s (la de la animación).
  double speedMps;

  /// Velocidad del tramo según el operador (m/s), para convertir minutos en metros.
  double segmentSpeedMps;

  /// Segundos que quedaban hasta [trackingStopIndex] cuando se recibió el dato.
  double? etaSeconds;

  /// Rescans completos seguidos en los que no se ha vuelto a detectar.
  int missedScans;

  SimulatedBus({
    required this.lineId,
    required this.busId,
    required this.currentPosition,
    this.heading = 0,
    this.speed = 1.0,
    this.currentStopIndex = 0,
    this.nextStopIndex = 1,
    this.progress = 0,
    this.isAtStop = false,
    this.departureTime,
    this.lastKnownMinutes,
    this.trackingStopId,
    this.trackingStopIndex,
    this.gpsTrack,
    this.trackFromIndex = 0,
    this.trackToIndex = 0,
    this.lastApiUpdate,
    this.targetProgress = 0,
    this.distance = 0,
    this.speedMps = 0,
    this.segmentSpeedMps = BusSimulationService.defaultSpeedMps,
    this.etaSeconds,
    this.missedScans = 0,
  });
}

/// Bus detectado en un escaneo: antes de la parada [stopIndex], a [minutes].
@visibleForTesting
class DetectedBus {
  DetectedBus(this.stopIndex, this.minutes, this.distance, this.segmentSpeedMps);
  final int stopIndex;
  final int minutes;
  final double distance;
  final double segmentSpeedMps;
}

class BusSimulationService {
  BusSimulationService();

  /// Reloj de la simulación (los tests lo sustituyen para controlar el tiempo).
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  final BusTimesService _busTimesService = BusTimesService();
  final Map<String, SimulatedBus> _buses = {};
  final Map<String, List<Map<String, dynamic>>> _lineStops = {};
  final Map<String, RouteGeometry> _geometry = {};
  final Map<String, double> _lineSpeed = {};
  int _nextBusNumber = 1;

  Timer? _updateTimer;
  Timer? _trackingTimer;
  Timer? _rescanTimer;
  DateTime? _lastTick;
  bool _isTracking = false;
  bool _isRescanning = false;
  StreamController<Map<String, SimulatedBus>>? _busStreamController;
  bool _isDisposed = false;

  // ── Parámetros del modelo ──
  static const double _tickSeconds = 0.5;

  /// Velocidad media por defecto (≈14 km/h con paradas, medida en la L1).
  static const double defaultSpeedMps = 4.0;
  static const double _minSpeedMps = 2.0;
  static const double _maxSegmentSpeedMps = 12.0;

  /// Velocidad máxima de la animación (≈50 km/h): nunca hay saltos.
  static const double maxSpeedMps = 14.0;

  /// Tiempo de reacción al perseguir la posición objetivo.
  static const double _tauSeconds = 8.0;

  /// Más de esto en minutos se considera "no viene en esta vuelta".
  static const int maxUsefulMinutes = 75;

  /// Si pasa más tiempo que esto entre ticks (app en segundo plano), se
  /// recoloca el bus directamente en lugar de animar el recorrido.
  static const double _resyncAfterSeconds = 20;

  Stream<Map<String, SimulatedBus>> get busStream {
    _busStreamController ??= StreamController<Map<String, SimulatedBus>>.broadcast(
      onListen: () {
        if (_buses.isNotEmpty && !_isDisposed) {
          _busStreamController?.add(_buses);
        }
      },
    );
    return _busStreamController!.stream;
  }

  Map<String, SimulatedBus> get buses => Map.unmodifiable(_buses);

  void _emitBuses() {
    if (!_isDisposed && _busStreamController != null && !_busStreamController!.isClosed) {
      _busStreamController!.add(_buses);
    }
  }

  void setLineStops(String lineId, List<Map<String, dynamic>> stops) {
    _lineStops[lineId] = stops;
    _geometry.remove(lineId);
  }

  List<Map<String, dynamic>>? getLineStops(String lineId) => _lineStops[lineId];

  @visibleForTesting
  RouteGeometry? geometryOf(String lineId) => _geometry[lineId];

  /// Para tests: usar un recorrido concreto en lugar del de assets.
  @visibleForTesting
  void setGeometry(String lineId, List<LatLng> track) {
    final stops = _lineStops[lineId] ?? const [];
    _geometry[lineId] = RouteGeometry.build(track, stops.map(_stopLatLng).toList());
  }

  Future<RouteGeometry?> _ensureGeometry(String lineId) async {
    final cached = _geometry[lineId];
    if (cached != null) return cached;
    final stops = _lineStops[lineId];
    if (stops == null || stops.length < 2) return null;
    final track = await GpsTrackService.loadTrack(lineId);
    final geo = RouteGeometry.build(track, stops.map(_stopLatLng).toList());
    _geometry[lineId] = geo;
    return geo;
  }

  void startSimulation() {
    _lastTick = clock();
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(
      Duration(milliseconds: (_tickSeconds * 1000).toInt()),
      (_) => _tick(),
    );
    _trackingTimer?.cancel();
    _trackingTimer = Timer.periodic(const Duration(seconds: 20), (_) => _trackBuses());
    // Escaneo completo cada 3 min: detecta buses nuevos y quita los que ya no están.
    _rescanTimer?.cancel();
    _rescanTimer = Timer.periodic(const Duration(minutes: 3), (_) => _rescan());
  }

  void stopSimulation() {
    _updateTimer?.cancel();
    _trackingTimer?.cancel();
    _rescanTimer?.cancel();
    _updateTimer = null;
    _trackingTimer = null;
    _rescanTimer = null;
  }

  // ───────────────────────── Lectura de tiempos ─────────────────────────

  /// Minutos hasta la llegada, o null si el texto no se entiende.
  /// "< < <" / "llegando" → 0; "12 min" → 12; "21:40" → minutos hasta esa hora.
  @visibleForTesting
  static int? parseMinutes(String timeStr, {DateTime? now}) {
    final s = timeStr.trim().toLowerCase();
    if (s.isEmpty) return null;
    if (s.contains('<') || s.contains('llegando') || s.contains('&lt;')) return 0;
    final clock = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s);
    if (clock != null) {
      final n = now ?? DateTime.now();
      var t = DateTime(n.year, n.month, n.day, int.parse(clock.group(1)!), int.parse(clock.group(2)!));
      if (t.isBefore(n.subtract(const Duration(minutes: 5)))) t = t.add(const Duration(days: 1));
      return max(0, t.difference(n).inSeconds ~/ 60);
    }
    final mins = RegExp(r"^(\d{1,3})\s*(min|m|')?\.?$").firstMatch(s);
    if (mins != null) return int.parse(mins.group(1)!);
    return null;
  }

  /// Segundos aproximados que representa un tiempo del operador en minutos enteros.
  static double _etaSeconds(int minutes) => minutes <= 0 ? 0 : minutes * 60.0 - 30;

  /// Minutos de la línea en cada parada (índice de parada → minutos), consultando
  /// [indices] con 6 peticiones a la vez. Las paradas sin dato no aparecen.
  Future<Map<int, int>> _fetchLineMinutes(String lineId, Iterable<int> indices, {Duration reuse = const Duration(seconds: 15)}) async {
    final stops = _lineStops[lineId]!;
    final result = <int, int>{};
    final pending = indices.toList();
    var next = 0;
    Future<void> worker() async {
      while (next < pending.length) {
        final k = pending[next++];
        try {
          final stopId = stops[k]['id'] as int;
          // Paradas compartidas entre líneas: si se acaban de consultar, no se repite.
          final arrivals = BusTimesService.cachedArrivals(stopId, maxAge: reuse) ?? await _busTimesService.getArrivalTimes(stopId);
          int? best;
          for (final a in arrivals) {
            if (a.line.trim().toUpperCase() != lineId) continue;
            final m = parseMinutes(a.time);
            if (m != null && (best == null || m < best)) best = m;
          }
          if (best != null) result[k] = best;
        } catch (e) {
          debugPrint('Error en parada ${stops[k]['id']}: $e');
        }
      }
    }

    await Future.wait(List.generate(min(6, pending.length), (_) => worker()));
    return result;
  }

  // ───────────────────────── Detección de buses ─────────────────────────

  /// Velocidad media de la línea según el operador: distancia entre paradas
  /// seguidas de un mismo bus dividida entre la diferencia de sus minutos.
  /// Usa tramos largos en conjunto, así el redondeo a minutos casi no influye.
  @visibleForTesting
  static double lineSpeedFrom(RouteGeometry geo, Map<int, int> minutesByStop) {
    final n = geo.stopCount;
    var meters = 0.0, seconds = 0.0;
    for (var j = 0; j < n; j++) {
      final a = minutesByStop[j], b = minutesByStop[(j + 1) % n];
      if (a == null || b == null || a > maxUsefulMinutes || b > maxUsefulMinutes || b < a || b - a > 20) continue;
      meters += geo.forward(geo.stopDistances[j], geo.stopDistances[(j + 1) % n]);
      seconds += (b - a) * 60;
    }
    if (seconds < 120) return defaultSpeedMps;
    return (meters / seconds).clamp(_minSpeedMps, _maxSegmentSpeedMps).toDouble();
  }

  /// Velocidad para llegar a la parada [k] (con [m] min) desde la siguiente
  /// ([next] min). Con menos de 2 min de diferencia el redondeo la falsea y
  /// se usa la media de la línea.
  static double segmentSpeed(RouteGeometry geo, int k, int m, int? next, double lineSpeed) {
    if (next == null || next > maxUsefulMinutes || next - m < 2) return lineSpeed;
    final n = geo.stopCount;
    final d = geo.forward(geo.stopDistances[k], geo.stopDistances[(k + 1) % n]);
    return (d / ((next - m) * 60)).clamp(_minSpeedMps, _maxSegmentSpeedMps).toDouble();
  }

  /// Detecta los buses de una línea a partir de los minutos de cada parada.
  ///
  /// Recorriendo las paradas en orden, un bus está justo antes de la parada j
  /// cuando sus minutos son menores que los de la parada anterior (en la
  /// anterior ya se espera al bus siguiente). Si la parada siguiente da un
  /// tiempo enorme, ese bus termina el servicio ahí y no se simula.
  @visibleForTesting
  static List<DetectedBus> detectBuses(RouteGeometry geo, Map<int, int> minutesByStop) {
    final n = geo.stopCount;
    final detected = <DetectedBus>[];
    if (n < 2) return detected;
    final lineSpeed = lineSpeedFrom(geo, minutesByStop);

    for (var j = 0; j < n; j++) {
      final m = minutesByStop[j];
      if (m == null || m > maxUsefulMinutes) continue;
      final prev = minutesByStop[(j - 1 + n) % n];
      if (prev != null && prev <= maxUsefulMinutes && prev <= m) continue; // es el mismo bus que viene de atrás
      final nextIdx = (j + 1) % n;
      final next = minutesByStop[nextIdx];
      if (next != null && (next > maxUsefulMinutes || next < m)) continue; // termina el servicio aquí

      final v = segmentSpeed(geo, j, m, next, lineSpeed);
      final prevDist = geo.forward(geo.stopDistances[(j - 1 + n) % n], geo.stopDistances[j]);
      // Un bus "antes de j" tiene que poder llegar desde la parada anterior en
      // esos minutos (a 2 m/s y con 10 min de margen por si regula). Si no, es
      // el tiempo de otro bus que da la vuelta entera: no hay bus ahí.
      if (m > prevDist / _minSpeedMps / 60 + 10) continue;
      final back = min(_etaSeconds(m) * v, max(0.0, prevDist - 5)); // no más atrás que la parada anterior
      detected.add(DetectedBus(j, m, geo.wrap(geo.stopDistances[j] - back), v));
    }
    return detected;
  }

  /// Escaneo inicial: consulta todas las paradas para encontrar buses.
  Future<void> initialScan(List<Map<String, dynamic>> allStops) async {
    debugPrint('=== ESCANEO INICIAL DE TODAS LAS PARADAS ===');
    await _scanAllLines(initial: true);
    debugPrint('=== ESCANEO COMPLETO: ${_buses.length} buses encontrados ===');
    _emitBuses();
  }

  @visibleForTesting
  Future<void> rescanNow() => _rescan();

  @visibleForTesting
  Future<void> trackNow() => _trackBuses();

  Future<void> _rescan() async {
    if (_isRescanning || _isDisposed) return;
    _isRescanning = true;
    try {
      await _scanAllLines(initial: false);
      _emitBuses();
    } finally {
      _isRescanning = false;
    }
  }

  Future<void> _scanAllLines({required bool initial}) async {
    for (final lineId in _lineStops.keys.toList()) {
      final geo = await _ensureGeometry(lineId);
      if (geo == null) continue;
      final minutes = await _fetchLineMinutes(lineId, List.generate(geo.stopCount, (i) => i));
      if (minutes.isNotEmpty) _lineSpeed[lineId] = lineSpeedFrom(geo, minutes);
      final detected = detectBuses(geo, minutes);
      _reconcile(lineId, geo, detected, initial: initial);
    }
  }

  /// Junta lo detectado con los buses que ya había: actualiza su dato de
  /// llegada (sin moverlos de golpe), crea los nuevos y quita los que llevan
  /// dos escaneos sin aparecer.
  void _reconcile(String lineId, RouteGeometry geo, List<DetectedBus> detected, {required bool initial}) {
    final existing = _buses.values.where((b) => b.lineId == lineId).toList();
    final matched = <SimulatedBus>{};
    final now = clock();

    for (final d in detected) {
      SimulatedBus? best;
      var bestGap = double.infinity;
      for (final b in existing) {
        if (matched.contains(b)) continue;
        // Distancia con signo de la posición actual a la detectada (−L/2..L/2).
        var gap = geo.forward(b.distance, d.distance);
        if (gap > geo.length / 2) gap -= geo.length;
        if (gap < -400 || gap > 1500) continue;
        if (gap.abs() < bestGap) {
          bestGap = gap.abs();
          best = b;
        }
      }
      if (best != null) {
        matched.add(best);
        best.missedScans = 0;
        _setEta(best, geo, d.stopIndex, d.minutes, d.segmentSpeedMps, now);
      } else {
        final bus = SimulatedBus(
          lineId: lineId,
          busId: '$lineId#${_nextBusNumber++}',
          currentPosition: geo.positionAt(d.distance),
          distance: d.distance,
          segmentSpeedMps: d.segmentSpeedMps,
        );
        _setEta(bus, geo, d.stopIndex, d.minutes, d.segmentSpeedMps, now);
        _updateDerived(bus, geo);
        _buses[bus.busId] = bus;
        debugPrint('==> Bus ${bus.busId}: antes de la parada ${d.stopIndex} en ${d.minutes} min');
      }
    }

    if (!initial) {
      for (final b in existing) {
        if (matched.contains(b)) continue;
        if (++b.missedScans >= 2) _buses.remove(b.busId);
      }
    }
  }

  void _setEta(SimulatedBus bus, RouteGeometry geo, int stopIndex, int minutes, double v, DateTime now) {
    final stops = _lineStops[bus.lineId]!;
    bus.trackingStopIndex = stopIndex;
    bus.trackingStopId = stops[stopIndex]['id'] as int;
    bus.etaSeconds = _etaSeconds(minutes);
    bus.lastApiUpdate = now;
    bus.lastKnownMinutes = minutes;
    bus.segmentSpeedMps = v;
  }

  // ───────────────────────── Seguimiento ─────────────────────────

  /// Cada 20 s: consulta la próxima parada de cada bus (y la siguiente para
  /// la velocidad del tramo). Solo acepta tiempos coherentes con donde está
  /// el bus; si no, son de otro bus y se ignoran.
  Future<void> _trackBuses() async {
    if (_isTracking || _isDisposed) return;
    _isTracking = true;
    try {
      await Future.wait(_buses.values.toList().map(_trackBus));
      _emitBuses();
    } finally {
      _isTracking = false;
    }
  }

  Future<void> _trackBus(SimulatedBus bus) async {
    final geo = _geometry[bus.lineId];
    if (geo == null) return;
    final n = geo.stopCount;
    final k = geo.nextStopIndex(bus.distance);
    final k2 = (k + 1) % n;
    final k3 = (k + 2) % n;
    final minutes = await _fetchLineMinutes(bus.lineId, [k, k2, k3], reuse: const Duration(seconds: 5));

    // Primero la próxima parada; si su dato no encaja (el bus real ya la ha
    // pasado y marca el de la vuelta siguiente), la de después.
    for (final (stop, following) in [(k, k2), (k2, k3)]) {
      final m = minutes[stop];
      if (m == null || m > maxUsefulMinutes) continue;
      if (!_plausible(bus, geo, stop, m)) continue;
      final v = segmentSpeed(geo, stop, m, minutes[following], _lineSpeed[bus.lineId] ?? bus.segmentSpeedMps);
      _setEta(bus, geo, stop, m, v, clock());
      return;
    }
  }

  /// ¿Puede ser de este bus que la parada [stop] diga [m] minutos?
  /// Mucho MENOS de lo esperado: hay otro bus entre este y la parada → no.
  /// Más de lo esperado sí (va lento o está regulando en una parada).
  /// Lo esperado es lo que tardaría por distancia o, si es más, lo que aún le
  /// quedaba según su último dato (p. ej. un bus que espera en la parada).
  bool _plausible(SimulatedBus bus, RouteGeometry geo, int stop, int m) {
    final ahead = geo.forward(bus.distance, geo.stopDistances[stop]);
    var expectedSec = ahead / bus.segmentSpeedMps;
    if (bus.trackingStopIndex == stop && bus.etaSeconds != null && bus.lastApiUpdate != null) {
      final remaining = bus.etaSeconds! - clock().difference(bus.lastApiUpdate!).inMilliseconds / 1000;
      expectedSec = max(expectedSec, remaining);
    }
    final expectedMin = expectedSec / 60;
    return m >= expectedMin - (2 + 0.3 * expectedMin) && m <= expectedMin + 20;
  }

  // ───────────────────────── Movimiento ─────────────────────────

  /// Distancia (con signo, respecto a [bus.distance]) a la que debería estar
  /// el bus ahora según su último dato de llegada. Nunca pasa de la parada
  /// siguiente a la del dato: sin datos nuevos, el bus espera ahí.
  double _targetAhead(SimulatedBus bus, RouteGeometry geo, DateTime now) {
    final k = bus.trackingStopIndex;
    if (k == null || bus.etaSeconds == null || bus.lastApiUpdate == null) return bus.segmentSpeedMps * _tickSeconds;
    var toStop = geo.forward(bus.distance, geo.stopDistances[k]);
    if (toStop > geo.length / 2) toStop -= geo.length; // ya ha pasado la parada
    final elapsed = now.difference(bus.lastApiUpdate!).inMilliseconds / 1000;
    final remaining = bus.etaSeconds! - elapsed;
    var target = toStop - remaining * bus.segmentSpeedMps;
    final n = geo.stopCount;
    final limit = toStop + geo.forward(geo.stopDistances[k], geo.stopDistances[(k + 1) % n]) - 20;
    if (target > limit) target = limit;
    return target;
  }

  void _tick() {
    final now = clock();
    final dt = _lastTick == null ? _tickSeconds : now.difference(_lastTick!).inMilliseconds / 1000;
    _lastTick = now;
    advance(dt, now);
  }

  /// Avanza la simulación [dt] segundos. Público para los tests.
  @visibleForTesting
  void advance(double dt, [DateTime? now]) {
    final t = now ?? clock();
    var changed = false;
    for (final bus in _buses.values) {
      final geo = _geometry[bus.lineId];
      if (geo == null) continue;
      final ahead = _targetAhead(bus, geo, t);
      double move;
      if (dt > _resyncAfterSeconds) {
        // Volvemos de segundo plano: recolocar sin animar el camino.
        move = max(0.0, min(ahead, 3000.0));
      } else {
        final v = (ahead / _tauSeconds).clamp(0.0, maxSpeedMps);
        move = v * dt;
        if (move > ahead) move = max(0.0, ahead);
      }
      bus.speedMps = dt > 0 ? move / dt : 0;
      if (move > 0) {
        bus.distance = geo.wrap(bus.distance + move);
        changed = true;
      }
      _updateDerived(bus, geo, t);
    }
    if (changed) _emitBuses();
  }

  /// Rellena los campos que usa la interfaz a partir de [bus.distance].
  void _updateDerived(SimulatedBus bus, RouteGeometry geo, [DateTime? now]) {
    bus.currentPosition = geo.positionAt(bus.distance);
    bus.heading = geo.headingAt(bus.distance);
    final n = geo.stopCount;
    final next = geo.nextStopIndex(bus.distance, margin: 0);
    final prev = (next - 1 + n) % n;
    bus.nextStopIndex = next;
    bus.currentStopIndex = prev;
    final seg = geo.forward(geo.stopDistances[prev], geo.stopDistances[next]);
    bus.progress = seg <= 0 ? 0 : (geo.forward(geo.stopDistances[prev], bus.distance) / seg).clamp(0.0, 1.0);
    final nearStop = min(geo.forward(bus.distance, geo.stopDistances[next]), geo.forward(geo.stopDistances[prev], bus.distance));
    bus.isAtStop = nearStop < 25 && bus.speedMps < 0.8;
    bus.speed = bus.speedMps / defaultSpeedMps;
    if (bus.etaSeconds != null && bus.lastApiUpdate != null) {
      final remaining = bus.etaSeconds! - (now ?? clock()).difference(bus.lastApiUpdate!).inSeconds;
      bus.lastKnownMinutes = max(0, (remaining / 60).ceil());
    }
  }

  LatLng _stopLatLng(Map<String, dynamic> stop) => LatLng((stop['lat'] as num).toDouble(), (stop['lng'] as num).toDouble());

  void dispose() {
    _isDisposed = true;
    stopSimulation();
    _busStreamController?.close();
  }
}
