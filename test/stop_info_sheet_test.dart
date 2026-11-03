// La ficha de una parada se abre con los tiempos guardados al momento y no
// vuelve a mostrar el indicador de carga al refrescar.

import 'dart:typed_data';

import 'package:alzitrans/constants/app_config.dart';
import 'package:alzitrans/core/network/api_client.dart';
import 'package:alzitrans/core/providers/tts_provider.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import 'package:alzitrans/models/bus_stop.dart';
import 'package:alzitrans/services/bus_times_service.dart';
import 'package:alzitrans/services/tts_service.dart';
import 'package:alzitrans/widgets/stop_info_sheet.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SilentTts extends TtsService {
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> speakQueued(String text) async {}
}

/// Responde tras [delay] con un HTML del operador con [time] en la L1.
class SlowOperator implements HttpClientAdapter {
  SlowOperator(this.delay, this.time);
  final Duration delay;
  String time;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    await Future<void>.delayed(delay);
    return ResponseBody.fromString(
      '<table><tr><th>L</th><th>D</th><th>T</th></tr><tr><td>L1</td><td>ESTACIO RENFE</td><td>$time</td></tr></table>',
      200,
    );
  }

  @override
  void close({bool force = false}) {}
}

Widget sheet(BusStop stop) => ProviderScope(
      overrides: [ttsProvider.overrideWithValue(SilentTts())],
      child: MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: StopInfoSheet(stop: stop))),
      ),
    );

void main() {
  late HttpClientAdapter original;
  setUpAll(() {
    original = ApiClient().dio.httpClientAdapter;
    AppConfig.showAds = false;
  });
  tearDownAll(() => ApiClient().dio.httpClientAdapter = original);

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('con tiempos guardados se ven al instante, sin indicador de carga', (tester) async {
    final adapter = SlowOperator(const Duration(milliseconds: 500), '12 min');
    ApiClient().dio.httpClientAdapter = adapter;
    final stop = BusStop(id: 3001, name: 'PLAÇA DEL REGNE', lat: 39.15, lng: -0.43, lines: ['L1']);

    // Rellena la caché como lo haría el escaneo inicial.
    adapter.time = '4 min';
    await tester.runAsync(() => BusTimesService().getArrivalTimes(3001));
    adapter.time = '3 min';

    await tester.pumpWidget(sheet(stop));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('4 min'), findsOneWidget, reason: 'tiempo guardado mostrado al abrir');

    // Llega la respuesta nueva: se actualiza sin pasar por el indicador.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(find.textContaining('3 min'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // El banner de anuncios espera hasta 20 s a AdMob (aquí desactivado).
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpWidget(const SizedBox()); // cierra la ficha: cancela el refresco cada 30 s
  });

  testWidgets('sin tiempos guardados muestra la carga y luego los tiempos', (tester) async {
    ApiClient().dio.httpClientAdapter = SlowOperator(const Duration(milliseconds: 300), '7 min');
    final stop = BusStop(id: 3002, name: 'HOSPITAL', lat: 39.14, lng: -0.44, lines: ['L1']);

    await tester.pumpWidget(sheet(stop));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.textContaining('7 min'), findsOneWidget);

    await tester.pump(const Duration(seconds: 21));
    await tester.pumpWidget(const SizedBox());
  });
}
