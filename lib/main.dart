// No action needed: 'pages/splash_page.dart' is not imported.
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import 'services/foreground_service.dart';
import 'services/stops_service.dart';
import 'services/bus_alert_service.dart';
import 'services/trip_history_service.dart';
import 'services/assistant_service.dart';
import 'services/notices_service.dart';
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
import 'services/tts_service.dart';
import 'dart:async';

// Clave global para la navegación (necesaria para mostrar diálogos desde servicios)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Inicialización crítica (rápida)
  final prefs = await SharedPreferences.getInstance();
  final authService = AuthService();
  final isLoggedIn = await authService.isLoggedIn();
  
  // 2. Lanzar la interfaz de usuario INMEDIATAMENTE
  runApp(AlzitransApp(isLoggedIn: isLoggedIn));
  
  // 3. Todo lo pesado (API, Simulaciones, Servicios de fondo) se carga después sin bloquear
  Future.microtask(() async {
    if (!kIsWeb) {
      await ForegroundService.initialize();
      await BusAlertService().initialize();
      AssistantService.initialize();
      SocketService().initialize();
      await TtsService().init();
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
    final busSimService = BusSimulationService();
    
    // CRÍTICO: Registrar las paradas de cada línea ANTES del escaneo inicial
    // Usamos loadLineRoute para que el orden y las paradas repetidas (circulares)
    // coincidan exactamente con el JSON de la ruta, igual que en RoutesPage.
    for (final line in ['L1', 'L2', 'L3']) {
      final routeStops = await stopsService.loadLineRoute(line);
      busSimService.setLineStops(line, routeStops);
      debugPrint('Main: Registradas ${routeStops.length} paradas (en orden de ruta) para línea $line');
    }
    
    await busSimService.initialScan(stopsData);
    busSimService.startSimulation();
    
    if (!kIsWeb) {
      await _requestPermissions();
      final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      if (notificationsEnabled) {
        await ForegroundService.start();
      }
    }
  });
}

/// Solicita todos los permisos necesarios para el foreground service
Future<void> _requestPermissions() async {
  // 1. Permiso de notificaciones (Android 13+)
  await Permission.notification.request();
  
  // 2. Permiso de ubicación (primero foreground)
  final locationStatus = await Permission.location.request();
  
  if (locationStatus.isGranted) {
    // 3. Permiso de ubicación en segundo plano (CRÍTICO para foreground service)
    // Android requiere que primero tengas el permiso de ubicación normal
    final bgStatus = await Permission.locationAlways.request();
    
    if (!bgStatus.isGranted) {
      debugPrint('⚠️ Permiso de ubicación en segundo plano denegado');
    }
  }
}

// Handler para notificaciones en segundo plano (debe ser top-level)
@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) async {
  final action = response.actionId;
  if (action == null) return;
  final prefs = await SharedPreferences.getInstance();
  final historyService = TripHistoryService(prefs);
  final authService = AuthService();
  final token = await authService.getToken();
  if (action == 'confirm_trip' && token != null) {
    await historyService.confirmTrip(token);
  } else if (action == 'reject_trip') {
    await historyService.rejectTrip();
  }
}

class AlzitransApp extends StatefulWidget {
  final bool isLoggedIn;
  
  const AlzitransApp({super.key, required this.isLoggedIn});

  @override
  State<AlzitransApp> createState() => _AlzitransAppState();
}

class _AlzitransAppState extends State<AlzitransApp> {
  Locale _currentLocale = const Locale('es');

  @override
  void initState() {
    super.initState();
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('app_locale') ?? 'es';
    if (mounted) setState(() => _currentLocale = Locale(code));
    TtsService().setLanguage(code);
  }

  void _onLocaleChanged(Locale locale) {
    setState(() => _currentLocale = locale);
    TtsService().setLanguage(locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Alzitrans',
      theme: AlzitransTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      locale: _currentLocale,
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
      home: widget.isLoggedIn
          ? HomePage(onLocaleChanged: _onLocaleChanged, currentLocale: _currentLocale)
          : const LoginPage(),
      routes: {
        '/login': (context) => const LoginPage(),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  final Function(Locale)? onLocaleChanged;
  final Locale currentLocale;

  const HomePage({
    super.key,
    this.onLocaleChanged,
    this.currentLocale = const Locale('es'),
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _index = 0;
  final FlutterLocalNotificationsPlugin _notif = FlutterLocalNotificationsPlugin();
  bool _notificationsEnabled = true;
  double _notificationDistance = 80.0;
  int _notificationCooldown = 5;
  bool _isShowingTripDialog = false; // Para evitar mostrar múltiples diálogos
  int _noticesCount = 0; // Número de avisos activos
  
  // Heartbeat timer
  Timer? _heartbeatTimer;
  final AuthService _authService = AuthService();
  
  // Nuevos ajustes
  bool _showSimulatedBuses = true;
  bool _autoRefreshTimes = true;
  bool _vibrationEnabled = true;
  bool _ttsEnabled = false;
  
  // Para navegar a una parada desde Rutas
  final GlobalKey<MapPageState> _mapPageKey = GlobalKey<MapPageState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initNotifications();
    _loadPreferences();
    _loadNoticesCount();
    
    // Iniciar heartbeat cada 2 minutos
    _startHeartbeat();
    
    // Verificar viaje pendiente después de que el widget esté completamente construido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pequeño delay para asegurar que el contexto esté listo
      Future.delayed(const Duration(milliseconds: 500), () {
        _checkPendingTrip();
      });
    });
  }

  Future<void> _loadNoticesCount() async {
    final service = NoticesService();
    final notices = await service.loadNotices();
    final prefs = await SharedPreferences.getInstance();
    final lastSeenStr = prefs.getString('last_seen_notices_at');
    final lastSeen = lastSeenStr != null ? DateTime.tryParse(lastSeenStr) : null;

    final unseenCount = lastSeen == null
        ? notices.length
        : notices.where((n) => n.createdAt.isAfter(lastSeen)).length;

    if (mounted) setState(() => _noticesCount = unseenCount);
  }
  
  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    // Primer pulso inmediato
    _authService.sendHeartbeat();
    
    // Pulsos periódicos cada 2 minutos
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _authService.sendHeartbeat();
    });
  }
  
  // Cuando la app vuelve al frente, comprobar viaje pendiente y reanudar heartbeat
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingTrip();
      _startHeartbeat();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _heartbeatTimer?.cancel();
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _notificationDistance = prefs.getDouble('notification_distance') ?? 80.0;
      _notificationCooldown = prefs.getInt('notification_cooldown') ?? 5;
      _showSimulatedBuses = prefs.getBool('show_simulated_buses') ?? true;
      _autoRefreshTimes = prefs.getBool('auto_refresh_times') ?? true;
      _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
      _ttsEnabled = prefs.getBool('tts_enabled') ?? false;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setDouble('notification_distance', _notificationDistance);
    await prefs.setInt('notification_cooldown', _notificationCooldown);
    await prefs.setBool('show_simulated_buses', _showSimulatedBuses);
    await prefs.setBool('auto_refresh_times', _autoRefreshTimes);
    await prefs.setBool('vibration_enabled', _vibrationEnabled);
    await prefs.setBool('tts_enabled', _ttsEnabled);
    TtsService().isEnabled = _ttsEnabled;
  }

  Future<void> _initNotifications() async {
    // En web no inicializamos notificaciones nativas
    if (kIsWeb) {
      return;
    }
    
    const android = AndroidInitializationSettings('@drawable/ic_launcher_foreground');
    const initSettings = InitializationSettings(android: android);
    await _notif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
    );
  }
  
  Future<void> _checkPendingTrip() async {
    // Evitar mostrar múltiples diálogos
    if (_isShowingTripDialog) return;
    
    final prefs = await SharedPreferences.getInstance();
    final historyService = TripHistoryService(prefs);
    final pending = historyService.getPendingTrip();
    
    debugPrint('[TripDialog] Checking pending trip: ${pending != null ? "FOUND" : "none"}');
    if (pending != null) {
      debugPrint('[TripDialog] Pending trip data: $pending');
      
      final tripData = pending; // Capturar en variable local para el callback
      // Hay un viaje pendiente, mostrar diálogo después de que se construya el widget
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isShowingTripDialog) {
          _showTripConfirmDialog(tripData);
        }
      });
    }
  }
  
  void _showTripConfirmDialog(Map<String, dynamic> trip) {
    _isShowingTripDialog = true;
    
    // Calcular hace cuánto fue el viaje
    final timestamp = DateTime.tryParse(trip['timestamp'] ?? '');
    String timeAgo = '';
    if (timestamp != null) {
      final diff = DateTime.now().difference(timestamp);
      if (diff.inMinutes < 60) {
        timeAgo = 'Hace ${diff.inMinutes} minutos';
      } else if (diff.inHours < 24) {
        timeAgo = 'Hace ${diff.inHours} hora${diff.inHours > 1 ? 's' : ''}';
      } else {
        timeAgo = 'Hace ${diff.inDays} día${diff.inDays > 1 ? 's' : ''}';
      }
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono grande
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AlzitransColors.burgundy.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_bus, size: 50, color: AlzitransColors.burgundy),
              ),
              const SizedBox(height: 20),
              
              // Título
              const Text(
                '¿Cogiste el bus?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // Info del viaje
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AlzitransColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AlzitransColors.burgundy,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Línea ${trip['line']}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (timeAgo.isNotEmpty) ...[
                          const Spacer(),
                          Text(timeAgo, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: AlzitransColors.coral, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            trip['stopName'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    if (trip['destination'] != null && trip['destination'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.arrow_forward, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '→ ${trip['destination']}',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              
              Text(
                'Registra tus viajes para ver estadísticas',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Botones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        _isShowingTripDialog = false;
                        final prefs = await SharedPreferences.getInstance();
                        final historyService = TripHistoryService(prefs);
                        await historyService.rejectTrip();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('👍 Entendido, no se registró'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('No'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        _isShowingTripDialog = false;
                        final prefs = await SharedPreferences.getInstance();
                        final historyService = TripHistoryService(prefs);
                        final authService = AuthService();
                        final token = await authService.getToken();
                        if (token != null) {
                          await historyService.confirmTrip(token);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('¡Viaje registrado!'),
                                ],
                              ),
                              backgroundColor: AlzitransColors.success,
                              duration: const Duration(seconds: 2),
                              action: SnackBarAction(
                                label: 'Ver historial',
                                textColor: Colors.white,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const TripHistoryScreen()),
                                  );
                                },
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('¡Sí!'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AlzitransColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      _isShowingTripDialog = false;
    });
  }
  
  void _onNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    
    // Si tocó la notificación de "bus llegando", mostrar diálogo
    if (payload == 'trip_confirm') {
      final prefs = await SharedPreferences.getInstance();
      final historyService = TripHistoryService(prefs);
      final pending = historyService.getPendingTrip();
      
      if (pending != null) {
        // Esperar a que el contexto esté disponible
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showTripConfirmDialog(pending);
        });
      }
      return;
    }
    
    // Para acciones de botones (si las hubiera)
    final action = response.actionId;
    if (action == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final historyService = TripHistoryService(prefs);
    
    if (action == 'confirm_trip') {
      final authService = AuthService();
      final token = await authService.getToken();
      if (token != null) await historyService.confirmTrip(token);
    } else if (action == 'reject_trip') {
      await historyService.rejectTrip();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    void pushSettings() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SettingsPage(
            notificationsEnabled: _notificationsEnabled,
            notificationDistance: _notificationDistance,
            notificationCooldown: _notificationCooldown,
            showSimulatedBuses: _showSimulatedBuses,
            autoRefreshTimes: _autoRefreshTimes,
            vibrationEnabled: _vibrationEnabled,
            ttsEnabled: _ttsEnabled,
            onNotificationsChanged: (value) async {
              setState(() => _notificationsEnabled = value);
              await _savePreferences();
              if (value) {
                await ForegroundService.start();
              } else {
                await ForegroundService.stop();
              }
            },
            onDistanceChanged: (value) {
              setState(() => _notificationDistance = value);
              _savePreferences();
            },
            onCooldownChanged: (value) {
              setState(() => _notificationCooldown = value);
              _savePreferences();
            },
            onShowSimulatedBusesChanged: (value) {
              setState(() => _showSimulatedBuses = value);
              _savePreferences();
            },
            onAutoRefreshTimesChanged: (value) {
              setState(() => _autoRefreshTimes = value);
              _savePreferences();
            },
            onVibrationChanged: (value) {
              setState(() => _vibrationEnabled = value);
              _savePreferences();
            },
            onTtsChanged: (value) {
              setState(() => _ttsEnabled = value);
              _savePreferences();
            },
            currentLocale: widget.currentLocale,
            onLocaleChanged: (locale) {
              widget.onLocaleChanged?.call(locale);
            },
          ),
        ),
      );
    }

    final pages = [
      // 0 — Mapa
      MapPage(
        key: _mapPageKey,
        notif: _notif,
        notificationsEnabled: _notificationsEnabled,
        notificationDistance: _notificationDistance,
        notificationCooldown: _notificationCooldown,
        showSimulatedBuses: _showSimulatedBuses,
      ),
      // 1 — Rutas
      RoutesPage(
        onStopTapped: (stop) {
          setState(() => _index = 0);
          Future.delayed(const Duration(milliseconds: 100), () {
            _mapPageKey.currentState?.goToStop(stop);
          });
        },
      ),
      // 2 — NFC
      const NfcPage(),
      // 3 — Avisos
      const NoticesScreen(),
      // 4 — Perfil
      ProfileScreen(onSettingsTap: pushSettings),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l.appTitle),
        actions: [
          // Único botón en AppBar: alertas activas (operacional, tiempo real)
          IconButton(
            icon: const Icon(Icons.notifications_active),
            tooltip: l.activeAlerts,
            iconSize: 28,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ActiveAlertsScreen(
                    onViewStop: (stopId, stopName) {
                      setState(() => _index = 0);
                      Future.delayed(const Duration(milliseconds: 100), () {
                        _mapPageKey.currentState?.goToStopById(stopId);
                      });
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          // Refrescar contador de avisos al volver a la pestaña
          if (i == 3) _loadNoticesCount();
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map),
            label: l.tabMap,
          ),
          NavigationDestination(
            icon: const Icon(Icons.route_outlined),
            selectedIcon: const Icon(Icons.route),
            label: l.tabRoutes,
          ),
          NavigationDestination(
            icon: const Icon(Icons.nfc_outlined),
            selectedIcon: const Icon(Icons.nfc),
            label: l.tabNfc,
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _noticesCount > 0,
              label: Text('$_noticesCount'),
              child: const Icon(Icons.campaign_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: _noticesCount > 0,
              label: Text('$_noticesCount'),
              child: const Icon(Icons.campaign),
            ),
            label: l.notices,
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

