// Tests de las optimizaciones de rendimiento (escaneo en paralelo, caché de
// tiempos por parada y X-API-Key solo hacia nuestro API).
//
// No usan la red: un adaptador falso de Dio responde con HTML como el de la
// web del operador y apunta qué peticiones llegan y cuántas van a la vez.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:alzitrans/core/network/api_client.dart';
import 'package:alzitrans/services/bus_simulation_service.dart';
import 'package:alzitrans/services/bus_times_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String operatorHtml(List<List<String>> rows) {
  final trs = rows.map((r) => '<tr><td>${r[0]}</td><td>${r[1]}</td><td>${r[2]}</td></tr>').join();
  return '<html><body><table><tr><th>Línea</th><th>Destino</th><th>Tiempo</th></tr>$trs</table></body></html>';
}

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter({this.delay = Duration.zero, this.handler});

  final Duration delay;
  final ResponseBody Function(RequestOptions options)? handler;
  final List<RequestOptions> requests = [];
  int inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      return handler?.call(options) ?? ResponseBody.fromString(operatorHtml([]), 200);
    } finally {
      inFlight--;
    }
  }

  @override
  void close({bool force = false}) {}
}

int? stopIdOf(RequestOptions o) => int.tryParse(o.uri.queryParameters['id'] ?? '');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpClientAdapter originalAdapter;

  setUpAll(() => originalAdapter = ApiClient().dio.httpClientAdapter);
  tearDownAll(() => ApiClient().dio.httpClientAdapter = originalAdapter);

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('ApiClient', () {
    test('la X-API-Key va a nuestro API y no al servidor del operador', () async {
      final adapter = FakeAdapter(handler: (_) => ResponseBody.fromString('[]', 200, headers: {
            'content-type': ['application/json'],
          }));
      ApiClient().dio.httpClientAdapter = adapter;

      await ApiClient().get('/stops');
      await ApiClient().get('https://servidor.autocareslozano.es/Alzira/webtiempos/PopupPoste.aspx?id=1');

      expect(adapter.requests, hasLength(2));
      expect(adapter.requests[0].headers.containsKey('X-API-Key'), isTrue, reason: 'petición a nuestro API');
      expect(adapter.requests[1].headers.containsKey('X-API-Key'), isFalse, reason: 'petición al operador');
      expect(adapter.requests[1].headers.containsKey('Authorization'), isFalse);
    });
  });

  group('BusTimesService', () {
    test('lee los tiempos del HTML y los guarda en la caché', () async {
      ApiClient().dio.httpClientAdapter = FakeAdapter(
        handler: (_) => ResponseBody.fromString(operatorHtml([
          ['l1', 'ESTACIO RENFE', '5 min'],
          ['L2', 'HOSPITAL', '<<<'],
        ]), 200),
      );

      expect(BusTimesService.cachedArrivals(1001), isNull);
      final arrivals = await BusTimesService().getArrivalTimes(1001);

      expect(arrivals.map((a) => a.line), ['L1', 'L2']);
      expect(arrivals.first.destination, 'ESTACIO RENFE');
      final cached = BusTimesService.cachedArrivals(1001);
      expect(cached, isNotNull);
      expect(cached!.map((a) => a.time), ['5 min', '<<<']);
    });

    test('la caché caduca y no guarda respuestas con error', () async {
      ApiClient().dio.httpClientAdapter = FakeAdapter(
        handler: (o) => stopIdOf(o) == 1002
            ? ResponseBody.fromString(operatorHtml([['L3', 'CENTRE', '9 min']]), 200)
            : ResponseBody.fromString('error', 500),
      );

      await BusTimesService().getArrivalTimes(1002);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(BusTimesService.cachedArrivals(1002, maxAge: const Duration(milliseconds: 1)), isNull);
      expect(BusTimesService.cachedArrivals(1002), isNotNull);

      final failed = await BusTimesService().getArrivalTimes(1003);
      expect(failed, isEmpty);
      expect(BusTimesService.cachedArrivals(1003), isNull);
    });

    test('un fallo de red devuelve lista vacía sin lanzar', () async {
      ApiClient().dio.httpClientAdapter = FakeAdapter(handler: (o) => throw DioException(requestOptions: o, message: 'sin red'));
      expect(await BusTimesService().getArrivalTimes(1004), isEmpty);
    });
  });

  group('BusSimulationService.initialScan', () {
    List<Map<String, dynamic>> route(int n) => List.generate(n, (i) => {'id': 2000 + i, 'name': 'P$i', 'lat': 39.15 + i * 0.001, 'lng': -0.43});

    test('consulta como mucho 6 paradas a la vez, cada una una sola vez, y salta las de solo CEM', () async {
      final stops = [
        ...route(20).map((s) => {...s, 'lines': ['L1']}),
        {'id': 79, 'name': 'CEMENTERI', 'lat': 39.15, 'lng': -0.39, 'lines': ['CEM']},
        {'id': 0, 'name': 'SIN ID', 'lat': 39.15, 'lng': -0.39, 'lines': ['L1']},
      ];
      final adapter = FakeAdapter(
        delay: const Duration(milliseconds: 40),
        handler: (o) => ResponseBody.fromString(
            operatorHtml(stopIdOf(o) == 2010 ? [['L1', 'ESTACIO', '3 min']] : []), 200),
      );
      ApiClient().dio.httpClientAdapter = adapter;

      final sim = BusSimulationService()..setLineStops('L1', route(20));
      final sw = Stopwatch()..start();
      await sim.initialScan(stops);
      sw.stop();

      final ids = adapter.requests.map(stopIdOf).toList();
      expect(ids, hasLength(20));
      expect(ids.toSet(), hasLength(20), reason: 'ninguna parada se consulta dos veces');
      expect(ids, isNot(contains(79)), reason: 'la parada que solo es CEM no se consulta');
      expect(ids, isNot(contains(0)));
      expect(adapter.maxInFlight, inInclusiveRange(2, 6));
      // 20 paradas × 40 ms en serie serían 800 ms; en paralelo bastante menos.
      expect(sw.elapsedMilliseconds, lessThan(600));
      expect(sim.buses.keys, contains('L1'), reason: 'se crea el bus de la L1');
      sim.stopSimulation();
    });

    test('si todas las consultas fallan termina sin buses y sin lanzar', () async {
      ApiClient().dio.httpClientAdapter = FakeAdapter(handler: (o) => throw DioException(requestOptions: o, message: 'sin red'));
      final sim = BusSimulationService()..setLineStops('L1', route(8));
      await sim.initialScan(route(8).map((s) => {...s, 'lines': ['L1']}).toList());
      expect(sim.buses, isEmpty);
    });

    test('con una lista de paradas vacía no hace ninguna petición', () async {
      final adapter = FakeAdapter();
      ApiClient().dio.httpClientAdapter = adapter;
      final sim = BusSimulationService()..setLineStops('L1', route(3));
      await sim.initialScan([]);
      expect(adapter.requests, isEmpty);
      expect(sim.buses, isEmpty);
    });

    test('el escaneo deja los tiempos en la caché para las fichas de parada', () async {
      ApiClient().dio.httpClientAdapter = FakeAdapter(
        handler: (o) => ResponseBody.fromString(operatorHtml([['L1', 'HOSPITAL', '${stopIdOf(o)! % 10} min']]), 200),
      );
      final sim = BusSimulationService()..setLineStops('L1', route(5));
      await sim.initialScan(route(5).map((s) => {...s, 'lines': ['L1']}).toList());
      for (var i = 0; i < 5; i++) {
        expect(BusTimesService.cachedArrivals(2000 + i), isNotNull);
      }
      sim.stopSimulation();
    });
  });

  test('las paradas guardadas en prefs se pueden leer como espera el arranque', () async {
    // _startBusSimulation lee 'bus_stops' con jsonDecode → List<Map>.
    final data = [
      {'id': 1, 'name': 'A', 'lat': 39.1, 'lng': -0.4, 'lines': ['L1', 'CEM']},
    ];
    SharedPreferences.setMockInitialValues({'bus_stops': jsonEncode(data)});
    final prefs = await SharedPreferences.getInstance();
    final parsed = (jsonDecode(prefs.getString('bus_stops')!) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    expect(List<String>.from(parsed.first['lines'] as List), ['L1', 'CEM']);
  });
}
