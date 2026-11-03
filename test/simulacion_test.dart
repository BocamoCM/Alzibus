// Tests de la simulación de buses: recorridos sin saltos, lectura de tiempos,
// detección de buses (con datos reales del operador) y movimiento sin
// teletransportes ni retrocesos.

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:alzitrans/core/network/api_client.dart';
import 'package:alzitrans/services/bus_simulation_service.dart';
import 'package:alzitrans/services/bus_times_service.dart';
import 'package:alzitrans/services/route_geometry.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dist = Distance(roundResult: false);

List<Map<String, dynamic>> loadStops(String line) =>
    (jsonDecode(File('assets/routes/$line.json').readAsStringSync()) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

List<LatLng> loadTrack(String line) => (jsonDecode(File('assets/routes/${line}_gps.json').readAsStringSync()) as List)
    .map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
    .toList();

RouteGeometry geometryFor(String line) =>
    RouteGeometry.build(loadTrack(line), loadStops(line).map((s) => LatLng((s['lat'] as num).toDouble(), (s['lng'] as num).toDouble())).toList());

/// Línea recta de prueba: [n] paradas cada [gap] m hacia el norte, cerrada.
({List<Map<String, dynamic>> stops, List<LatLng> track}) straightLine(int n, double gap) {
  const start = LatLng(39.15, -0.43);
  final stops = List.generate(n, (i) {
    final p = _dist.offset(start, i * gap, 0);
    return {'id': 5000 + i, 'name': 'P$i', 'lat': p.latitude, 'lng': p.longitude, 'lines': ['T']};
  });
  // Vuelta: subir por el norte y volver por una paralela 100 m al este.
  final up = List.generate(n * 10, (i) => _dist.offset(start, i * gap / 10, 0));
  final top = _dist.offset(up.last, 100, 90);
  final down = List.generate(n * 10, (i) => _dist.offset(top, -i * gap / 10, 0));
  return (stops: stops, track: [...up, top, ...down]);
}

/// Adaptador que devuelve los minutos que diga [minutesFor] para cada parada.
class OperatorStub implements HttpClientAdapter {
  OperatorStub(this.minutesFor, {this.line = 'T'});
  String? Function(int stopId) minutesFor;
  final String line;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final id = int.parse(options.uri.queryParameters['id']!);
    final t = minutesFor(id);
    final row = t == null ? '' : '<tr><td>$line</td><td>DESTINO</td><td>$t</td></tr>';
    return ResponseBody.fromString('<table><tr><th>L</th><th>D</th><th>T</th></tr>$row</table>', 200);
  }

  @override
  void close({bool force = false}) {}
}

/// Hora simulada que usan los servicios en los tests.
late DateTime simNow;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpClientAdapter original;
  setUpAll(() => original = ApiClient().dio.httpClientAdapter);
  tearDownAll(() => ApiClient().dio.httpClientAdapter = original);
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    BusTimesService.clearCache();
    simNow = DateTime(2026, 11, 3, 17, 0);
  });

  group('Recorridos (assets)', () {
    for (final line in ['L1', 'L2', 'L3']) {
      test('$line: paradas en orden, cerca del recorrido y sin saltos', () {
        final geo = geometryFor(line);
        final stops = loadStops(line);
        expect(geo.length, greaterThan(5000));

        // Todas las paradas están en el recorrido (mapa oficial del operador).
        final off = [for (var k = 0; k < geo.stopCount; k++) if (geo.offRoute[k]) stops[k]['id']];
        expect(off, isEmpty);
        var last = -1.0;
        for (var k = 0; k < geo.stopCount; k++) {
          if (geo.offRoute[k]) continue;
          expect(geo.stopDistances[k], greaterThan(last), reason: 'parada $k (${stops[k]['name']}) antes que la anterior');
          last = geo.stopDistances[k];
        }
        for (var k = 0; k < geo.stopCount; k++) {
          if (geo.offRoute[k]) continue;
          final s = stops[k];
          final d = _dist(geo.positionAt(geo.stopDistances[k]), LatLng((s['lat'] as num).toDouble(), (s['lng'] as num).toDouble()));
          expect(d, lessThan(RouteGeometry.stopToleranceM), reason: '${s['name']} a ${d.round()} m del recorrido');
        }
        // Recorrer la vuelta entera cada 5 m: dos puntos seguidos nunca a más de 5,5 m.
        var prev = geo.positionAt(0);
        var maxJump = 0.0;
        for (var x = 5.0; x <= geo.length + 50; x += 5) {
          final p = geo.positionAt(x);
          maxJump = max(maxJump, _dist(prev, p));
          prev = p;
        }
        expect(maxJump, lessThan(5.5), reason: 'salto de ${maxJump.toStringAsFixed(1)} m');
      });
    }
  });

  group('parseMinutes', () {
    test('formatos del operador', () {
      final p = BusSimulationService.parseMinutes;
      expect(p('5 min'), 5);
      expect(p('12min'), 12);
      expect(p('241 min'), 241);
      expect(p('< < <'), 0);
      expect(p('&lt; &lt; &lt;'), 0);
      expect(p('Llegando'), 0);
      expect(p('Sin datos'), isNull);
      expect(p('--'), isNull);
      expect(p(''), isNull);
      expect(p('21:40', now: DateTime(2026, 11, 3, 21, 30)), 10);
      expect(p('00:10', now: DateTime(2026, 11, 3, 23, 50)), 20);
    });
  });

  group('detectBuses', () {
    test('datos reales de la L1 (3/11 17:27 y 18:27): el bus elegido es el que sigue la cadena de minutos', () {
      final geo = geometryFor('L1');
      // La parada 2 (CIPFP) daba 241 y 183 min: cifra fuera de rango, no se usa para colocar el bus.
      final a = <int, int>{0: 57, 1: 0, 2: 241, 3: 1, 4: 2, 5: 4, 6: 5, 7: 7, 8: 8, 9: 10, 10: 13, 11: 16, 12: 17, 13: 32, 14: 38, 15: 40, 16: 42, 17: 43, 18: 44, 19: 45, 20: 47, 21: 48, 22: 49, 23: 50, 24: 51, 25: 53};
      final best = BusSimulationService.bestDetection(BusSimulationService.detectBuses(geo, a))!;
      expect(best.stopIndex, 3, reason: 'el que encaja con las 22 paradas siguientes');
      final b = <int, int>{0: 0, 1: 1, 2: 183, 3: 3, 4: 4, 5: 6, 6: 7, 7: 9, 8: 10, 9: 12, 10: 15, 11: 18, 12: 19, 13: 34, 14: 40, 15: 42, 16: 44, 17: 45, 18: 46, 19: 47, 20: 49, 21: 50, 22: 51, 23: 52, 24: 53, 25: 55};
      final best2 = BusSimulationService.bestDetection(BusSimulationService.detectBuses(geo, b))!;
      expect(best2.stopIndex, 0, reason: 'en el Hospital ("< < <")');
      final v = BusSimulationService.lineSpeedFrom(geo, b);
      expect(v, inInclusiveRange(3.0, 6.0));
    });

    test('datos reales de la L1 (3/11 17:38): un bus en la parada 9', () {
      final geo = geometryFor('L1');
      final m = <int, int>{0: 45, 1: 47, 2: 241, 3: 51, 4: 52, 5: 54, 6: 55, 7: 57, 8: 58, 9: 0, 10: 3, 11: 6, 12: 7, 13: 22, 14: 28, 15: 30, 16: 32, 17: 33, 18: 34, 19: 35, 20: 37, 21: 38, 22: 39, 23: 40, 24: 41, 25: 43};
      expect(BusSimulationService.bestDetection(BusSimulationService.detectBuses(geo, m))!.stopIndex, 9);
    });

    test('dos buses reales a la vez (uno no puede llegar a tiempo a la parada del otro)', () {
      final geo = geometryFor('L1');
      // Bus A en la parada 1 y bus B a 1 min de la 10 (a ~5 km): imposible que sea el mismo.
      final m = <int, int>{1: 0, 3: 2, 4: 3, 5: 5, 6: 6, 7: 8, 8: 9, 9: 11, 10: 1, 11: 4, 12: 5};
      final buses = BusSimulationService.detectBuses(geo, m);
      expect(buses.map((b) => b.stopIndex).toList()..sort(), [1, 10]);
    });

    test('datos reales de la L1 (3/11 17:38): no inventa un bus donde solo llega el de la vuelta siguiente', () {
      final geo = geometryFor('L1');
      // Parada 2 con cifra fuera de lugar (241 min) y la 3 con el bus que ahora está en la 9 tras dar la vuelta.
      final m = <int, int>{0: 45, 1: 47, 2: 241, 3: 51, 4: 52, 5: 54, 6: 55, 7: 57, 8: 58, 9: 0, 10: 3, 11: 6, 12: 7, 13: 22, 14: 28, 15: 30, 16: 32, 17: 33, 18: 34, 19: 35, 20: 37, 21: 38, 22: 39, 23: 40, 24: 41, 25: 43};
      final buses = BusSimulationService.detectBuses(geo, m);
      expect(buses.map((b) => b.stopIndex).toList(), [9]);
    });

    test('dos buses en la misma línea se detectan por separado', () {
      final l = straightLine(10, 500);
      final geo = RouteGeometry.build(l.track, l.stops.map((s) => LatLng(s['lat'] as double, s['lng'] as double)).toList());
      final buses = BusSimulationService.detectBuses(geo, {0: 1, 1: 3, 2: 5, 3: 7, 4: 9, 5: 0, 6: 2, 7: 4, 8: 6, 9: 8});
      expect(buses.map((b) => b.stopIndex).toList()..sort(), [0, 5]);
    });

    test('sin datos o con todo fuera de servicio no inventa buses', () {
      final geo = geometryFor('L2');
      expect(BusSimulationService.detectBuses(geo, {}), isEmpty);
      expect(BusSimulationService.detectBuses(geo, {for (var i = 0; i < geo.stopCount; i++) i: 240}), isEmpty);
    });
  });

  group('Movimiento', () {
    Future<BusSimulationService> simWithBus(String Function(int stopIndex) minutes, {int stops = 10, double gap = 500}) async {
      final l = straightLine(stops, gap);
      ApiClient().dio.httpClientAdapter = OperatorStub((id) => minutes(id - 5000));
      final sim = BusSimulationService()
        ..clock = (() => simNow)
        ..setLineStops('T', l.stops);
      sim.setGeometry('T', l.track);
      await sim.initialScan(l.stops);
      return sim;
    }

    test('llega a la parada cuando dice el operador, sin saltos ni retrocesos', () async {
      // Bus antes de la parada 3: 4 min; luego 2 min por parada.
      final sim = await simWithBus((k) => k >= 3 ? '${4 + (k - 3) * 2} min' : '50 min');
      final bus = sim.buses.values.single;
      final geo = sim.geometryOf('T')!;
      final t0 = bus.lastApiUpdate!;
      var prev = bus.distance;
      var prevPos = bus.currentPosition;
      DateTime? arrived;
      for (var i = 1; i <= 8 * 60 * 2; i++) {
        final now = t0.add(Duration(milliseconds: 500 * i));
        simNow = now;
        sim.advance(0.5, now);
        final step = geo.forward(prev, bus.distance);
        expect(step, lessThanOrEqualTo(BusSimulationService.maxSpeedMps * 0.5 + 0.01), reason: 'paso de ${step.toStringAsFixed(1)} m');
        expect(_dist(prevPos, bus.currentPosition), lessThan(BusSimulationService.maxSpeedMps * 0.5 + 1));
        if (arrived == null && geo.forward(bus.distance, geo.stopDistances[3]) < 15) arrived = now;
        prev = bus.distance;
        prevPos = bus.currentPosition;
      }
      expect(arrived, isNotNull);
      final secs = arrived!.difference(t0).inSeconds;
      // "4 min" ≈ 3,5 min reales (minutos enteros): ±45 s.
      expect(secs, inInclusiveRange(210 - 45, 210 + 45));
      sim.stopSimulation();
    });

    test('sin datos nuevos espera antes de la parada siguiente en vez de seguir sin fin', () async {
      final sim = await simWithBus((k) => k == 3 ? '1 min' : (k == 4 ? '3 min' : null).toString().replaceAll('null', '--'));
      final bus = sim.buses.values.single;
      final geo = sim.geometryOf('T')!;
      final t0 = bus.lastApiUpdate!;
      for (var i = 1; i <= 30 * 60 * 2; i++) {
        simNow = t0.add(Duration(milliseconds: 500 * i));
        sim.advance(0.5, simNow);
      }
      final pastStop4 = geo.forward(geo.stopDistances[4], bus.distance);
      expect(pastStop4 > geo.length / 2 || pastStop4 < 1, isTrue, reason: 'no debe pasar de la parada 4 sin datos');
      expect(geo.forward(bus.distance, geo.stopDistances[4]), lessThan(60));
      sim.stopSimulation();
    });

    test('al volver de segundo plano se recoloca sin animar todo el camino', () async {
      final sim = await simWithBus((k) => k >= 3 ? '${3 + (k - 3) * 2} min' : '50 min');
      final bus = sim.buses.values.single;
      final geo = sim.geometryOf('T')!;
      final t0 = bus.lastApiUpdate!;
      final before = bus.distance;
      simNow = t0.add(const Duration(seconds: 150));
      sim.advance(150, simNow);
      final moved = geo.forward(before, bus.distance);
      expect(moved, greaterThan(100));
      expect(moved, lessThanOrEqualTo(3000));
      sim.stopSimulation();
    });

    test('ignora tiempos de otro bus (mucho menores de lo esperado)', () async {
      var phase = 0;
      final sim = await simWithBus((k) => phase == 0 ? (k >= 3 ? '${6 + (k - 3) * 2} min' : '50 min') : (k == 3 ? '0 min' : '50 min'));
      final bus = sim.buses.values.single;
      final eta = bus.etaSeconds;
      phase = 1; // ahora la parada 3 dice "0 min": es otro bus que va delante
      BusTimesService.clearCache();
      await sim.trackNow();
      expect(bus.etaSeconds, eta, reason: 'no debe adoptar el dato del otro bus');
      sim.stopSimulation();
    });

    test('como mucho un bus por línea aunque los datos parezcan de dos', () async {
      // Dos "trenes" de minutos: antes de la parada 0 y antes de la 5.
      const m = {0: 1, 1: 3, 2: 5, 3: 7, 4: 9, 5: 0, 6: 2, 7: 4, 8: 6, 9: 8};
      var data = Map<int, int>.of(m);
      final sim = await simWithBus((k) => data[k] == null ? '--' : '${data[k]} min');
      expect(sim.buses, hasLength(1));
      final id = sim.buses.keys.single;
      expect(id, 'T');
      // Otro escaneo con un tercer "bus" en la parada 8: sigue habiendo uno.
      data = {...m, 8: 0, 9: 2};
      BusTimesService.clearCache();
      await sim.rescanNow();
      expect(sim.buses, hasLength(1));
      expect(sim.buses.keys.single, id);
      sim.stopSimulation();
    });

    test('si los datos dejan de encajar con el bus, se recoloca (no se duplica)', () async {
      var phase = 0;
      final sim = await simWithBus((k) => phase == 0 ? (k >= 3 ? '${4 + (k - 3) * 2} min' : '50 min') : (k == 8 ? '1 min' : (k == 9 ? '3 min' : '--')));
      final geo = sim.geometryOf('T')!;
      expect(sim.buses.values.single.nextStopIndex, 3);
      phase = 1; // el operador ahora lo da antes de la parada 8 (lejos de donde iba)
      for (var i = 0; i < 2; i++) {
        BusTimesService.clearCache();
        await sim.rescanNow();
      }
      expect(sim.buses, hasLength(1));
      final bus = sim.buses.values.single;
      expect(geo.nextStopIndex(bus.distance), 8);
      sim.stopSimulation();
    });

    test('rescan: actualiza el bus existente, y lo quita tras dos escaneos sin verlo', () async {
      var on = true;
      final sim = await simWithBus((k) => !on ? '--' : (k >= 3 ? '${4 + (k - 3) * 2} min' : '50 min'));
      final id = sim.buses.keys.single;
      await sim.rescanNow();
      expect(sim.buses.keys.single, id, reason: 'mismo bus, no uno nuevo');
      on = false;
      BusTimesService.clearCache();
      await sim.rescanNow();
      expect(sim.buses, hasLength(1), reason: 'un escaneo sin verlo aún no lo quita');
      await sim.rescanNow();
      expect(sim.buses, isEmpty);
      sim.stopSimulation();
    });

    test('vuelta completa a la L1 real con datos en cada parada: nunca salta ni retrocede', () async {
      final stops = loadStops('L1');
      final geo = geometryFor('L1');
      const v = 4.0;
      // Minutos según la distancia real desde la posición inicial (justo antes de la parada 1).
      double busAt = geo.stopDistances[1] - 100;
      String timeFor(int k) {
        final ahead = geo.forward(busAt, geo.stopDistances[k]);
        return '${(ahead / v / 60).ceil()} min';
      }

      ApiClient().dio.httpClientAdapter = OperatorStub((id) => timeFor(stops.indexWhere((s) => s['id'] == id)), line: 'L1');
      final sim = BusSimulationService()
        ..clock = (() => simNow)
        ..setLineStops('L1', stops);
      sim.setGeometry('L1', loadTrack('L1'));
      await sim.initialScan(stops);
      final bus = sim.buses.values.firstWhere((b) => b.lineId == 'L1');

      var now = simNow;
      var prev = bus.distance, prevPos = bus.currentPosition;
      var travelled = 0.0, maxStep = 0.0;
      for (var i = 1; i <= 75 * 60 * 2 && travelled < geo.length; i++) {
        now = now.add(const Duration(milliseconds: 500));
        simNow = now;
        busAt = geo.wrap(busAt + v * 0.5); // el bus "real"
        if (i % 40 == 0) {
          BusTimesService.clearCache();
          await sim.trackNow(); // cada 20 s, como en la app
        }
        sim.advance(0.5, now);
        final step = geo.forward(prev, bus.distance);
        expect(step, lessThan(geo.length / 2), reason: 'retroceso');
        maxStep = max(maxStep, step);
        expect(_dist(prevPos, bus.currentPosition), lessThan(BusSimulationService.maxSpeedMps * 0.5 + 1), reason: 'salto en el mapa');
        travelled += step;
        prev = bus.distance;
        prevPos = bus.currentPosition;
      }
      expect(maxStep, lessThanOrEqualTo(BusSimulationService.maxSpeedMps * 0.5 + 0.01));
      expect(travelled, greaterThan(geo.length * 0.9), reason: 'debe completar casi toda la vuelta en 75 min');
      // Sigue cerca del bus "real" (error por redondeo de minutos).
      var err = geo.forward(bus.distance, busAt);
      if (err > geo.length / 2) err = geo.length - err;
      expect(err, lessThan(600));
      sim.stopSimulation();
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
