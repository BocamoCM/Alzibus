// No action needed: 'pages/splash_page.dart' is not imported.
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/network/api_client.dart';
import 'core/router/app_router.dart';

import 'screens/home_screen.dart';
import 'services/foreground_service.dart';
import 'services/stops_service.dart';
import 'services/bus_alert_service.dart';
import 'services/trip_history_service.dart';
import 'services/assistant_service.dart';
import 'services/notices_service.dart';
import 'constants/app_config.dart';
import 'theme/app_theme.dart';
import 'pages/map_page.dart';
import 'pages/nfc_page.dart';
import 'pages/settings_page.dart';
import 'pages/routes_page.dart';
import 'pages/login_page.dart';
import 'screens/trip_history_screen.dart';
import 'screens/active_alerts_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notices_screen.dart';
import 'services/auth_service.dart';
import 'services/socket_service.dart';
import 'services/bus_simulation_service.dart';
import 'services/gamification_service.dart';
import 'services/install_tracking_service.dart';
import 'core/providers/gamification_provider.dart';
import 'services/tts_service.dart';
import 'core/providers/tts_provider.dart';
import 'services/ad_service.dart';
import 'providers/high_visibility_provider.dart';
import 'services/premium_service.dart';
import 'widgets/ad_banner_widget.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/bus_simulation_provider.dart';
import 'core/providers/ad_provider.dart';
import 'core/providers/premium_provider.dart';
import 'widgets/location_permission_dialog.dart';
import 'dart:async';

// Clave global para la navegación (necesaria para mostrar diálogos desde servicios)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Asegurar inicialización antes de nada para usar PackageInfo
  WidgetsFlutterBinding.ensureInitialized();
  
  final packageInfo = await PackageInfo.fromPlatform();
  final version = packageInfo.version;
  final buildNumber = packageInfo.buildNumber;
  final packageName = packageInfo.packageName;

  await SentryFlutter.init(
    (options) {
      options.dsn = AppConfig.sentryDsn;
      
      // Configuración de Releases y Entornos
      options.environment = kDebugMode ? 'debug' : (kReleaseMode ? 'production' : 'staging');
      
      // Formato de release: package@version+build (y commit si existe)
      String releaseName = '$packageName@$version+$buildNumber';
      if (AppConfig.commitHash != 'none') {
        releaseName += '-${AppConfig.commitHash}';
      }
      options.release = releaseName;
      
      // Set tracesSampleRate to 1.0 to capture 100% of transactions for performance monitoring.
      options.tracesSampleRate = 1.0;
      
      options.enableAppLifecycleBreadcrumbs = true;
      options.enableWindowMetricBreadcrumbs = true;
      
      // Habilitar logs en consola para depuración
      if (kDebugMode) {
        options.debug = true;
      }
    },
    appRunner: () async {
      // Asegurar inicialización dentro del Zone de Sentry para evitar "Zone mismatch" en Web
      // Aunque ya se llamó fuera, volver a llamarlo aquí asegura el vínculo con el Zone actual.
      WidgetsFlutterBinding.ensureInitialized();
      
      // 1. Inicialización crítica (rápida)
      final prefs = await SharedPreferences.getInstance();
      
      // Inicializar rastreo de instalaciones (asíncrono, no bloqueante)
      InstallTrackingService.checkAndSendReferrer(prefs).catchError((e) {
        debugPrint('Error en tracking de instalación: $e');
      });

      final authService = AuthService();
      final isLoggedIn = await authService.isLoggedIn();
      
      // Inicializar Stripe
      // 2. Lanzar la interfaz de usuario INMEDIATAMENTE
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      // Inicializar servicios a través del container para cumplir con DI
      debugPrint('Main: Inicializando servicios a través de Providers...');
      
      // Premium
      if (!kIsWeb) {
        try {
          await container.read(premiumServiceProvider).init();
        } catch (e) {
          debugPrint('Main: Error inicializando PremiumService: $e');
        }
      }

      // AdMob
      if (!kIsWeb) {
        final adService = container.read(adServiceProvider);
        await adService.initialize();
        adService.preloadNativeAds();
      }

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const AlzitransApp(),
        ),
      );

  // Establecer identidad en Sentry si ya ha iniciado sesión
  if (isLoggedIn) {
    final userEmail = prefs.getString('user_email');
    final userId = prefs.getInt('user_id');
    if (userEmail != null && userId != null) {
      Sentry.configureScope((scope) {
        scope.setUser(SentryUser(id: userId.toString(), email: userEmail));
      });
    }
  }
      // 3. Todo lo pesado (API, Simulaciones, Servicios de fondo) se carga después sin bloquear
      Future.microtask(() async {
        // ESPERAR a que termine la lógica de permisos/avisos
        if (!kIsWeb) {
          await _requestPermissions();
        }
        
        // Reutilizamos prefs inicializado arriba o cargamos de nuevo si es necesario
        // pero evitamos redeclarar 'final prefs' si ya existe en el ámbito.
        await prefs.reload();
        final backgroundDisabled = prefs.getBool('background_location_disabled') ?? false;
        
        if (!kIsWeb) {
          // Solo iniciar servicios de segundo plano si el permiso NO ha sido rechazado
          // y el de sistema NO está denegado totalmente.
          if (!backgroundDisabled) {
            await ForegroundService.initialize();
            await BusAlertService().initialize();
          }
          
          AssistantService.initialize();
          SocketService().initialize();
          GamificationService().initialize();
          await container.read(ttsProvider).init();
          await container.read(localeProvider.notifier).loadLocale();
        } else {
          // Lógica simplificada para Web
          SocketService().initialize();
          await container.read(localeProvider.notifier).loadLocale();
        }

        final stopsService = StopsService();
        final stops = await stopsService.loadStops();
        debugPrint('Main: Paradas cargadas en segundo plano: ${stops.length}');
        
        final stopsData = stops.map((stop) => {
          'id': stop.id,
          'name': stop.name,
          'lat': stop.lat,
          'lng': stop.lng,
          'lines': stop.lines,
        }).toList();
        
        await prefs.setString('bus_stops', jsonEncode(stopsData));
        
        // Iniciar simulación global
        final busSimService = container.read(busSimulationProvider);
        
        // CRÍTICO: Registrar las paradas de cada línea ANTES del escaneo inicial
        for (final line in ['L1', 'L2', 'L3']) {
          final routeStops = await stopsService.loadLineRoute(line);
          busSimService.setLineStops(line, routeStops);
          debugPrint('Main: Registradas ${routeStops.length} paradas (en orden de ruta) para línea $line');
        }
        
        await busSimService.initialScan(stopsData);
        busSimService.startSimulation();
      });
    },
  );
}

Future<void> _requestPermissions() async {
  // 1. Verificar si ya tenemos el de segundo plano
  if (await Permission.locationAlways.isGranted) return;

  // 2. Verificar si el usuario ya rechazó explícitamente en esta sesión (o permanentemente)
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('background_location_disabled') == true) return;

  // 3. Esperar a que el contexto esté disponible (máximo 5 segundos)
  int attempts = 0;
  while (navigatorKey.currentContext == null && attempts < 10) {
    await Future.delayed(const Duration(milliseconds: 500));
    attempts++;
  }

  final context = navigatorKey.currentContext;
  if (context != null) {
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LocationPermissionDialog(),
    );

    if (proceed == true) {
      // 4. Pedir Notificaciones ahora que han aceptado ver el aviso
      await Permission.notification.request();

      // 5. Pedir Ubicación Foreground (primero, obligatorio en Android 10+)
      final locationStatus = await Permission.location.request();
      
      if (locationStatus.isGranted) {
        // 6. Pedir Ubicación en Segundo Plano (inmediatamente después)
        await Permission.locationAlways.request();
      }
    } else {
      // Si el usuario pulsa "No permitir", guardamos su preferencia
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_location_disabled', true);
      debugPrint('Main: El usuario ha rechazado explícitamente la ubicación en segundo plano');
    }
  }
}



class AlzitransApp extends ConsumerStatefulWidget {
  const AlzitransApp({super.key});

  @override
  ConsumerState<AlzitransApp> createState() => _AlzitransAppState();
}

class _AlzitransAppState extends ConsumerState<AlzitransApp> with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Notificar al backend que se ha abierto la app
    _notifyAppOpen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  void _notifyAppOpen() {
    try {
      ApiClient().post('/metrics/app-open').catchError((e) {
        debugPrint('Error notificando app-open: $e');
      });
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Mostrar App Open Ad al volver a la app
      ref.read(adServiceProvider).showAppOpenAdIfAvailable();
      
      // Notificar al backend
      _notifyAppOpen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(localeProvider);
    final isHighVisibility = ref.watch(highVisibilityProvider);
    
    final theme = isHighVisibility
        ? AlzitransTheme.lightTheme.copyWith(
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: AlzitransColors.burgundy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            iconTheme: const IconThemeData(size: 32, color: AlzitransColors.burgundy),
          )
        : AlzitransTheme.lightTheme;

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
          routerConfig: router,
          title: 'Alzitrans',
          theme: theme,
          debugShowCheckedModeBanner: false,
          locale: currentLocale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('es'),
            Locale('en'),
            Locale('ca'),
          ],
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: isHighVisibility
                    ? const TextScaler.linear(1.6)
                    : const TextScaler.linear(1.0),
              ),
              child: child!,
            );
          },
        );
  }
}

