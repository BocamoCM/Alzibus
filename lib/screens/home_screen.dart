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
import '../main.dart' show navigatorKey;
import '../core/router/app_router.dart';

import '../services/foreground_service.dart';
import '../services/stops_service.dart';
import '../services/bus_alert_service.dart';
import '../services/trip_history_service.dart';
import '../services/assistant_service.dart';
import '../services/notices_service.dart';
import '../constants/app_config.dart';
import '../theme/app_theme.dart';
import '../pages/map_page.dart';
import '../pages/nfc_page.dart';
import '../pages/settings_page.dart';
import '../pages/routes_page.dart';
import '../pages/login_page.dart';
import '../screens/trip_history_screen.dart';
import '../screens/active_alerts_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/notices_screen.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../services/bus_simulation_service.dart';
import '../services/tts_service.dart';
import '../core/providers/tts_provider.dart';
import '../services/ad_service.dart';
import '../providers/high_visibility_provider.dart';
import '../services/premium_service.dart';
import '../widgets/ad_banner_widget.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/ad_provider.dart';
import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';

// Handler para notificaciones en segundo plano (debe ser top-level)
@pragma('vm:entry-point')
void onBackgroundNotificationResponse(NotificationResponse response) async {
  final action = response.actionId;
  if (action == null) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final historyService = TripHistoryService(prefs);
  final authService = AuthService();
  final token = await authService.getToken();
  if (action == 'confirm_card' && token != null) {
    await historyService.confirmTrip(token, paymentMethod: 'card');
  } else if (action == 'confirm_cash' && token != null) {
    await historyService.confirmTrip(token, paymentMethod: 'cash');
  } else if (action == 'reject_trip') {
    await historyService.rejectTrip();
  }
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with WidgetsBindingObserver {
  int _index = 0;
  final FlutterLocalNotificationsPlugin _notif = FlutterLocalNotificationsPlugin();
  bool _notificationsEnabled = true;
  double _notificationDistance = 80.0;
  int _notificationCooldown = 5;
  bool _isShowingTripDialog = false; // Para evitar mostrar múltiples diálogos
  int _noticesCount = 0; // Número de avisos activos
  int _storedTrips = 0;
  bool _isUnlimited = false;
  
  // Heartbeat timer
  Timer? _heartbeatTimer;
  StreamSubscription? _assistantSubscription;
  StreamSubscription? _arrivalSubscription;
  StreamSubscription? _ipcSubscription; // Fix #3: retener suscripción IPC para poder cancelarla
  AuthService get _authService => ref.read(authServiceProvider);
  
  // Para intersticial al volver de background
  DateTime? _lastPausedTime;
  
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
    if (!kIsWeb) {
      _startHeartbeat();
    }
    
    // Verificar viaje pendiente inmediatamente al entrar
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkPendingTrip();
      
      // Arrancar el servicio de segundo plano
      if (!kIsWeb && _notificationsEnabled) {
        await ForegroundService.start();
      }
      
      // Precargar anuncios tras iniciar (esperando a que AdMob se inicialice)
      if (!kIsWeb) {
        final adService = ref.read(adServiceProvider);
        adService.initializationFuture.then((_) {
          adService.loadRewardedAd();
          adService.preloadNativeAds();
        });
      }
    });

    // Escuchar navegación desde Assistant / Shortcuts
    _assistantSubscription = AssistantService.navigationStream.listen((destination) {
      if (mounted) {
        setState(() {
          switch (destination) {
            case 'map':
              _index = 0;
              break;
            case 'bus_times': // "Ver buses"
              _index = 0;
              break;
            case 'favorites': // "Favoritos"
              _index = 1;
              break;
            case 'nfc': // "Escanear NFC"
              _index = 2;
              break;
            default:
              _index = 0;
          }
        });
      }
    });

    // Escuchar llegada de buses en tiempo real para mostrar diálogo instantáneo
    _arrivalSubscription = BusAlertService().onArrival.listen((pendingData) {
      debugPrint('[HomeScreen] Arrival stream event: $pendingData');
      if (mounted && !_isShowingTripDialog) {
        _showTripConfirmDialog(pendingData);
      }
    });

    // Escuchar IPC desde el ForegroundService (Isolate separado)
    if (!kIsWeb) {
      // Fix #3: Guardar la suscripción para poder cancelarla en dispose()
      _ipcSubscription = FlutterBackgroundService().on('bus_arrived').listen((event) {
        debugPrint('[HomeScreen] IPC "bus_arrived" received: $event');
        if (mounted && event != null && !_isShowingTripDialog) {
          _showTripConfirmDialog(event);
        }
      });
    }
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
    _assistantSubscription?.cancel();
    _arrivalSubscription?.cancel();
    _ipcSubscription?.cancel(); // Fix #3: cancelar suscripción IPC para evitar callbacks en widget destruido
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    // Fix #2: Comprobar token antes de hacer el primer pulso inmediato
    _authService.getToken().then((token) {
      if (token != null) _authService.sendHeartbeat();
    });
    
    // Pulsos periódicos cada 2 minutos, solo si hay sesión activa
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      final token = await _authService.getToken();
      if (token != null) _authService.sendHeartbeat();
    });
  }
  
  // Cuando la app vuelve al frente, comprobar viaje pendiente, reanudar heartbeat y mostrar ads
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final adService = ref.read(adServiceProvider);
    
    if (state == AppLifecycleState.resumed) {
      _checkPendingTrip();
      if (!kIsWeb) _startHeartbeat();
      
      // Mostrar App Open Ad al volver. Si se muestra, NO mostramos el intersticial también.
      final hadAppOpenAd = adService.hasAppOpenAdReady;
      adService.showAppOpenAdIfAvailable();
      
      // Mostrar Intersticial solo si NO había App Open Ad disponible
      if (!kIsWeb && !hadAppOpenAd) {
        adService.showInterstitialOnResume(_lastPausedTime);
      }
      _lastPausedTime = null;
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (!kIsWeb) _heartbeatTimer?.cancel();
      _lastPausedTime ??= DateTime.now();
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
      _storedTrips = prefs.getInt('stored_trips') ?? 0;
      _isUnlimited = prefs.getBool('is_unlimited') ?? false;
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
    ref.read(ttsProvider).isEnabled = _ttsEnabled;
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
      onDidReceiveBackgroundNotificationResponse: onBackgroundNotificationResponse,
    );
  }
  
  Future<void> _checkPendingTrip() async {
    // Evitar mostrar múltiples diálogos
    if (_isShowingTripDialog) return;
    
    // Solo mostrar si el usuario tiene sesión activa
    if (!await _authService.isLoggedIn()) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Recargar para ver cambios del background service
    
    // Sincronizar estado local con SharedPreferences
    if (mounted) {
      setState(() {
        _storedTrips = prefs.getInt('stored_trips') ?? 0;
        _isUnlimited = prefs.getBool('is_unlimited') ?? false;
      });
    }

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
                _isUnlimited 
                    ? 'Tienes viajes ILIMITADOS' 
                    : (_storedTrips > 0 
                        ? 'Se descontará 1 viaje de tu tarjeta (te quedan $_storedTrips)' 
                        : 'No tienes viajes en la tarjeta'),
                style: TextStyle(
                  color: _isUnlimited || _storedTrips > 0 ? Colors.green[700] : Colors.red[700],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Botones
              Column(
                children: [
                  Row(
                    children: [
                      /* BOTÓN TARJETA */
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            _isShowingTripDialog = false;
                            final prefs = await SharedPreferences.getInstance();
                            final historyService = TripHistoryService(prefs);
                            final token = await _authService.getToken();
                            if (token != null) {
                              await historyService.confirmTrip(token, paymentMethod: 'card');
                              await prefs.reload();
                              if (mounted) setState(() => _storedTrips = prefs.getInt('stored_trips') ?? 0);
                            }
                            if (mounted) _showTripRegisteredSnackBar(true);
                          },
                          icon: const Icon(Icons.credit_card, size: 18),
                          label: const Text('Con Tarjeta', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AlzitransColors.burgundy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      /* BOTÓN EFECTIVO */
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            _isShowingTripDialog = false;
                            final prefs = await SharedPreferences.getInstance();
                            final historyService = TripHistoryService(prefs);
                            final token = await _authService.getToken();
                            if (token != null) {
                              await historyService.confirmTrip(token, paymentMethod: 'cash');
                            }
                            if (mounted) _showTripRegisteredSnackBar(false);
                          },
                          icon: const Icon(Icons.payments, size: 18),
                          label: const Text('En Efectivo', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!_isUnlimited && _storedTrips > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Text(
                        '💡 Paga en efectivo si no quieres usar tus viajes',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                    ),
                  const SizedBox(height: 12),
                  /* BOTÓN NO */
                  SizedBox(
                    width: double.infinity,
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
                      label: const Text('No he subido'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey[300]!),
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

  void _showTripRegisteredSnackBar(bool isCard) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(isCard ? '¡Viaje con Tarjeta registrado!' : '¡Viaje en Efectivo registrado!'),
          ],
        ),
        backgroundColor: isCard ? AlzitransColors.burgundy : Colors.green[700],
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Ver historial',
          textColor: Colors.white,
          onPressed: () {
            const TripHistoryRoute().push(context);
          },
        ),
      ),
    );
  }
  
  void _onNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    
    // Si tocó la notificación de "bus llegando", mostrar diálogo
    if (payload == 'trip_confirm') {
      if (!await _authService.isLoggedIn()) return;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
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
    await prefs.reload();
    final historyService = TripHistoryService(prefs);
    
    if (action == 'confirm_trip') {
      final token = await _authService.getToken();
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
                if (!kIsWeb) await ForegroundService.start();
              } else {
                if (!kIsWeb) await ForegroundService.stop();
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
          ref.read(adServiceProvider).trackStopQuery();
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
        title: const AdBannerWidget(isCollapsible: true),
        titleSpacing: 0, // Para aprovechar todo el espacio para el banner
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
                      ref.read(adServiceProvider).trackStopQuery();
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

