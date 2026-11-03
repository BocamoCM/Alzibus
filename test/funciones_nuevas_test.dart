// Tests de: consejos para descubrir funciones, aviso de lluvia/tráfico en el
// mapa y barra superior del mapa (búsqueda + filtro sin solaparse).

import 'package:alzitrans/l10n/app_localizations.dart';
import 'package:alzitrans/services/feature_tips_service.dart';
import 'package:alzitrans/services/traffic_service.dart';
import 'package:alzitrans/services/weather_service.dart';
import 'package:alzitrans/widgets/conditions_banner.dart';
import 'package:alzitrans/widgets/feature_tip_card.dart';
import 'package:alzitrans/widgets/map_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(Widget child, {Locale locale = const Locale('es'), double textScale = 1.0, double width = 412}) => ProviderScope(
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 900), textScaler: TextScaler.linear(textScale)),
          child: Scaffold(body: Center(child: SizedBox(width: width, child: child))),
        ),
      ),
    );

const rain = WeatherStatus(isRaining: true, precipitationMm: 2.0, weatherCode: 63);
const dry = WeatherStatus(isRaining: false, precipitationMm: 0, weatherCode: 0);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('FeatureTipsService', () {
    final t0 = DateTime(2026, 11, 3, 10);

    test('como mucho un consejo cada 6 horas', () async {
      final s = FeatureTipsService(await SharedPreferences.getInstance());
      final first = s.pick(now: t0, totalTrips: 5)!;
      await s.markShown(first, t0);
      expect(s.pick(now: t0.add(const Duration(hours: 5)), totalTrips: 5), isNull);
      expect(s.pick(now: t0.add(const Duration(hours: 6, minutes: 1)), totalTrips: 5), isNotNull);
    });

    test('van rotando sin repetir hasta haberlos visto todos', () async {
      final s = FeatureTipsService(await SharedPreferences.getInstance());
      final seen = <FeatureTip>[];
      var now = t0;
      for (var i = 0; i < FeatureTip.values.length; i++) {
        final tip = s.pick(now: now, totalTrips: 10)!;
        seen.add(tip);
        await s.markShown(tip, now);
        now = now.add(const Duration(hours: 7));
      }
      expect(seen.toSet(), FeatureTip.values.toSet(), reason: 'salen todos: $seen');
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i], isNot(seen[i - 1]));
      }
    });

    test('el del CO₂ solo sale si el usuario tiene viajes', () async {
      final s = FeatureTipsService(await SharedPreferences.getInstance());
      var now = t0;
      for (var i = 0; i < 20; i++) {
        final tip = s.pick(now: now, totalTrips: 0)!;
        expect(tip, isNot(FeatureTip.co2));
        await s.markShown(tip, now);
        now = now.add(const Duration(hours: 7));
      }
    });

    test('"No mostrar más" los desactiva para siempre', () async {
      final s = FeatureTipsService(await SharedPreferences.getInstance());
      await s.disableForever();
      expect(s.pick(now: t0, totalTrips: 3), isNull);
      final again = FeatureTipsService(await SharedPreferences.getInstance());
      expect(again.pick(now: t0.add(const Duration(days: 30)), totalTrips: 3), isNull);
    });
  });

  group('ConditionsBanner', () {
    testWidgets('con lluvia aparece el aviso, se encoge a un chip y se vuelve a abrir', (tester) async {
      await tester.pumpWidget(app(ConditionsBanner(
        loadWeather: () async => rain,
        loadTraffic: () async => const TrafficStatus(incidentCount: 0),
        collapseAfter: const Duration(seconds: 10),
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const Key('conditions_card')), findsOneWidget);
      expect(find.text('Lluvia en Alzira'), findsOneWidget);

      await tester.pump(const Duration(seconds: 11));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('conditions_card')), findsNothing);
      expect(find.byKey(const Key('conditions_chip')), findsOneWidget);
      expect(find.text('Lluvia'), findsOneWidget);

      await tester.tap(find.byKey(const Key('conditions_chip')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('conditions_card')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('con tráfico denso avisa del tráfico; con lluvia y tráfico, de los dos', (tester) async {
      await tester.pumpWidget(app(ConditionsBanner(
        loadWeather: () async => rain,
        loadTraffic: () async => const TrafficStatus(incidentCount: 4),
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Tráfico denso'), findsOneWidget);
      expect(find.text('Lluvia en Alzira'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('sin lluvia ni tráfico, o si fallan las consultas, no ocupa nada', (tester) async {
      await tester.pumpWidget(app(ConditionsBanner(
        loadWeather: () async => dry,
        loadTraffic: () async => throw Exception('sin red'),
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const Key('conditions_card')), findsNothing);
      expect(find.byKey(const Key('conditions_chip')), findsNothing);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('la X lo encoge al momento', (tester) async {
      await tester.pumpWidget(app(ConditionsBanner(loadWeather: () async => rain, loadTraffic: () async => const TrafficStatus.unknown())));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const Key('conditions_close')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('conditions_chip')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('FeatureTipCard', () {
    testWidgets('aparece tras la espera, el botón abre la función y se va sola', (tester) async {
      FeatureTip? opened;
      await tester.pumpWidget(app(FeatureTipCard(
        delay: const Duration(seconds: 2),
        visibleFor: const Duration(seconds: 15),
        loadTotalTrips: () async => 12,
        onAction: (t) => opened = t,
      )));
      expect(find.byKey(const Key('feature_tip_action')), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('feature_tip_action')), findsOneWidget);

      await tester.tap(find.byKey(const Key('feature_tip_action')));
      await tester.pumpAndSettle();
      expect(opened, FeatureTip.games, reason: 'el primero de la rotación');
      expect(find.byKey(const Key('feature_tip_action')), findsNothing);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('el del CO₂ muestra los viajes y los kg ahorrados', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      // Que el siguiente de la rotación sea el del CO₂ (va después de "support").
      await prefs.setStringList('feature_tip_recent', ['games', 'support']);
      await tester.pumpWidget(app(FeatureTipCard(delay: Duration.zero, loadTotalTrips: () async => 40, onAction: (_) {})));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('feature_tip_co2')), findsOneWidget);
      // 40 viajes × 3 km × 0,113 kg/km ≈ 13,6 kg
      expect(find.textContaining('40 viajes'), findsOneWidget);
      expect(find.textContaining('13.6 kg'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('"No mostrar más" la cierra y no vuelve a salir', (tester) async {
      await tester.pumpWidget(app(FeatureTipCard(delay: Duration.zero, onAction: (_) {})));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('feature_tip_never')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('feature_tip_action')), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(FeatureTipsService(prefs).disabled, isTrue);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('si se ha enseñado hace poco no sale otro', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('feature_tip_last_shown', DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch);
      await tester.pumpWidget(app(FeatureTipCard(delay: Duration.zero, onAction: (_) {})));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('feature_tip_action')), findsNothing);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('MapTopBar', () {
    for (final width in [320.0, 360.0, 412.0]) {
      for (final locale in const [Locale('es'), Locale('ca'), Locale('en')]) {
        for (final scale in [1.0, 1.3]) {
          testWidgets('búsqueda y filtro no se pisan (${width.toInt()} px, ${locale.languageCode}, texto ×$scale)', (tester) async {
            tester.view.physicalSize = Size(width * 3, 2700);
            tester.view.devicePixelRatio = 3;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(app(
              MapTopBar(selectedLines: const {'L1', 'L2'}, onLineToggle: (_) {}, onSearchTap: () {}),
              locale: locale,
              textScale: scale,
              width: width - 32,
            ));
            final search = tester.getRect(find.byKey(const Key('map_search_bar')));
            final filter = tester.getRect(find.byKey(const Key('map_line_filter')));
            expect(search.right, lessThanOrEqualTo(filter.left - 8), reason: 'búsqueda $search, filtro $filter');
            expect(search.width, greaterThan(120), reason: 'la búsqueda tiene que seguir siendo usable');
            expect(tester.takeException(), isNull, reason: 'sin desbordamientos');
          });
        }
      }
    }
  });
}
