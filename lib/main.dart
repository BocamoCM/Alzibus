// No action needed: 'pages/splash_page.dart' is not imported.
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import 'services/foreground_service.dart';
import 'services/stops_service.dart';
import 'services/bus_alert_service.dart';
import 'services/trip_history_service.dart';
import 'services/assistant_service.dart';
import 'theme/app_theme.dart';
import 'pages/map_page.dart';
import 'pages/nfc_page.dart';
import 'pages/settings_page.dart';
import 'pages/routes_page.dart';
import 'pages/login_page.dart';
import 'screens/trip_history_screen.dart';
import 'screens/active_alerts_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar foreground service (solo Android/iOS)
  if (!kIsWeb) {
    await ForegroundService.initialize();
    
    // Inicializar servicio de alertas de bus
    await BusAlertService().initialize();
    
    // Inicializar servicio de Google Assistant
    AssistantService.initialize();
  }
  
  // Auto-confirmar viajes pendientes expirados
  final prefs = await SharedPreferences.getInstance();
  final historyService = TripHistoryService(prefs);
  final authService = AuthService();
  final token = await authService.getToken();
  if (token != null) {
    await historyService.autoConfirmIfExpired(token);
  }
  
  // Cargar y guardar paradas para el servicio de fondo
  final stopsService = StopsService();
  final stops = await stopsService.loadStops();
  debugPrint('Main: Paradas cargadas: ${stops.length}');
  final stopsData = stops.map((stop) => {
    'name': stop.name,
    'lat': stop.lat,
    'lng': stop.lng,
    'lines': stop.lines,
  }).toList();
  
  // Guardar paradas en preferences para el foreground service (en JSON)
  await prefs.setString('bus_stops', jsonEncode(stopsData));
  
  // Solicitar permisos necesarios (solo móvil)
  if (!kIsWeb) {
    await _requestPermissions();
    
    // Iniciar foreground service si las notificaciones están habilitadas
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    if (notificationsEnabled) {
      await ForegroundService.start();
    }
  }
  
  // Comprobar si el usuario ya está logueado (reutilizamos authService ya declarado arriba)
  final isLoggedIn = await authService.isLoggedIn();
  
  runApp(AlzibusApp(isLoggedIn: isLoggedIn));
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

class AlzibusApp extends StatelessWidget {
  final bool isLoggedIn;
  
  const AlzibusApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alzibus',
      theme: AlzibusTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: isLoggedIn ? const HomePage() : const LoginPage(),
      routes: {
        '/home': (context) => const HomePage(),
        '/login': (context) => const LoginPage(),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

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
  
  // Nuevos ajustes
  bool _showSimulatedBuses = true;
  bool _autoRefreshTimes = true;
  bool _vibrationEnabled = true;
  
  // Para navegar a una parada desde Rutas
  final GlobalKey<MapPageState> _mapPageKey = GlobalKey<MapPageState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Observar ciclo de vida
    _initNotifications();
    _loadPreferences();
    
    // Verificar viaje pendiente después de que el widget esté completamente construido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pequeño delay para asegurar que el contexto esté listo
      Future.delayed(const Duration(milliseconds: 500), () {
        _checkPendingTrip();
      });
    });
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  // Cuando la app vuelve al frente, comprobar viaje pendiente
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingTrip();
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
                  color: AlzibusColors.burgundy.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_bus, size: 50, color: AlzibusColors.burgundy),
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
                  color: AlzibusColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AlzibusColors.burgundy,
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
                        const Icon(Icons.location_on, color: AlzibusColors.coral, size: 20),
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
                              backgroundColor: AlzibusColors.success,
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
                        backgroundColor: AlzibusColors.success,
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
    // Obtener el servicio de simulación del MapPage si está disponible
    final busService = _mapPageKey.currentState?.busSimulationService;
    
    final pages = [
      MapPage(
        key: _mapPageKey,
        notif: _notif,
        notificationsEnabled: _notificationsEnabled,
        notificationDistance: _notificationDistance,
        notificationCooldown: _notificationCooldown,
        showSimulatedBuses: _showSimulatedBuses,
      ),
      RoutesPage(
        busSimulationService: busService,
        onStopTapped: (stop) {
          // Cambiar a la pestaña del mapa
          setState(() => _index = 0);
          // Ir a la parada
          Future.delayed(const Duration(milliseconds: 100), () {
            _mapPageKey.currentState?.goToStop(stop);
          });
        },
      ),
      const NfcPage(),
      SettingsPage(
        notificationsEnabled: _notificationsEnabled,
        notificationDistance: _notificationDistance,
        notificationCooldown: _notificationCooldown,
        showSimulatedBuses: _showSimulatedBuses,
        autoRefreshTimes: _autoRefreshTimes,
        vibrationEnabled: _vibrationEnabled,
        onNotificationsChanged: (value) async {
          setState(() => _notificationsEnabled = value);
          await _savePreferences();
          
          // Iniciar o detener foreground service
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
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alzibus — Alzira'),
        actions: [
          // Alertas activas
          IconButton(
            icon: const Icon(Icons.notifications_active),
            tooltip: 'Alertas activas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ActiveAlertsScreen(
                    onViewStop: (stopId, stopName) {
                      // Cambiar al mapa
                      setState(() => _index = 0);
                      // TODO: centrar en la parada
                    },
                  ),
                ),
              );
            },
          ),
          // Historial de viajes
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Historial de viajes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TripHistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
            BottomNavigationBarItem(icon: Icon(Icons.route), label: 'Rutas'),
            BottomNavigationBarItem(icon: Icon(Icons.nfc), label: 'NFC'),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Ajustes'),
          ],
          onTap: (i) => setState(() => _index = i)),
    );
  }
}
