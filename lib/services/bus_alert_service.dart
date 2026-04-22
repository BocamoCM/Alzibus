import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'bus_times_service.dart';
import 'notification_service.dart';
import '../infrastructure/storage/shared_prefs_adapter.dart';
import '../infrastructure/trips/local_trip_storage_impl.dart';

class BusAlert {
  final int stopId;
  final String stopName;
  final String line;
  final String destination;
  final DateTime createdAt;
  bool notified5min;
  bool notified2min;
  bool notifiedArriving;
  
  BusAlert({
    required this.stopId,
    required this.stopName,
    required this.line,
    required this.destination,
    required this.createdAt,
    this.notified5min = false,
    this.notified2min = false,
    this.notifiedArriving = false,
  });

  String get key => '${stopId}_${line}_${destination}';
  
  Map<String, dynamic> toJson() => {
    'stopId': stopId,
    'stopName': stopName,
    'line': line,
    'destination': destination,
    'createdAt': createdAt.toIso8601String(),
    'notified5min': notified5min,
    'notified2min': notified2min,
    'notifiedArriving': notifiedArriving,
  };
  
  factory BusAlert.fromJson(Map<String, dynamic> json) => BusAlert(
    stopId: int.parse(json['stopId'].toString()),
    stopName: json['stopName'].toString(),
    line: json['line'].toString(),
    destination: json['destination'].toString(),
    createdAt: DateTime.parse(json['createdAt'].toString()),
    notified5min: json['notified5min'].toString() == 'true',
    notified2min: json['notified2min'].toString() == 'true',
    notifiedArriving: json['notifiedArriving'].toString() == 'true',
  );
}

// Callback estático global para android_alarm_manager_plus
@pragma('vm:entry-point')
Future<void> checkAlertsCallback() async {
  final prefs = await SharedPreferences.getInstance();
  final alertsJson = prefs.getString('bus_alerts');
  
  if (alertsJson == null || alertsJson.isEmpty) {
    return;
  }
  
  try {
    final List<dynamic> list = jsonDecode(alertsJson);
    if (list.isEmpty) {
      return;
    }
    
    // Crear instancia del servicio
    final service = BusAlertService();
    
    // Cargar alertas desde SharedPreferences
    await service._loadAlerts();
    
    if (service._activeAlerts.isEmpty) {
      return;
    }
    
    // Inicializar plugin de notificaciones
    final notifPlugin = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@drawable/ic_launcher_foreground');
    await notifPlugin.initialize(const InitializationSettings(android: androidSettings));
    
    // Crear canal de notificación
    final androidPlugin = notifPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final alertsChannel = AndroidNotificationChannel(
      'alzibus-alerts',
      'Alertas de Bus',
      description: 'Te avisa cuando tu bus está llegando',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
      vibrationPattern: Int64List.fromList([0, 1000, 300, 1000]),
    );
    await androidPlugin?.createNotificationChannel(alertsChannel);
    
    // Inicializar servicios
    service._notificationService = NotificationService(notifPlugin);
    
    // Chequear alertas
    await service._checkAlerts();
  } catch (e) {
    // Registrar error en SharedPreferences para depuración
    await prefs.setString('last_alert_error', e.toString());
    await prefs.setString('last_alert_check', DateTime.now().toIso8601String());
  }
}

@pragma('vm:entry-point')
class BusAlertService {
  static final BusAlertService _instance = BusAlertService._internal();
  factory BusAlertService() => _instance;
  BusAlertService._internal();

  final _arrivalController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onArrival => _arrivalController.stream;

  final BusTimesService _busTimesService = BusTimesService();
  late final NotificationService _notificationService;
  final Map<String, BusAlert> _activeAlerts = {};
  final Set<String> _notifiedAlerts = {};
  Timer? _checkTimer;

  static const String _prefsKey = 'bus_alerts';

  Future<void> initialize() async {
    final notifPlugin = FlutterLocalNotificationsPlugin();
    _notificationService = NotificationService(notifPlugin);
    await _loadAlerts();
    if (_activeAlerts.isNotEmpty) {
      await _startMonitoring();
    }
  }

  Future<void> _loadAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final alertsJson = prefs.getString(_prefsKey);
    
    _activeAlerts.clear();
    if (alertsJson != null && alertsJson.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(alertsJson);
        for (final json in list) {
          final alert = BusAlert.fromJson(json);
          
          // Remover alertas de más de 2 horas
          if (DateTime.now().difference(alert.createdAt).inHours < 2) {
            _activeAlerts[alert.key] = alert;
          }
        }
      } catch (e) {
        // Ignorar alertas corruptas
      }
    }
  }

  Future<void> _saveAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final alertsList = _activeAlerts.values.map((alert) => alert.toJson()).toList();
    final alertsJson = jsonEncode(alertsList);
    await prefs.setString(_prefsKey, alertsJson);
  }

  Future<void> addAlert(BusAlert alert) async {
    _activeAlerts[alert.key] = alert;
    await _saveAlerts();
    
    // Iniciar monitoreo en segundo plano
    await _startMonitoring();
  }

  Future<void> removeAlert(String key) async {
    _activeAlerts.remove(key);
    _notifiedAlerts.remove(key);
    await _saveAlerts();
    
    // Detener monitoreo si no hay alertas
    if (_activeAlerts.isEmpty) {
      await _stopMonitoring();
    }
  }

  // Método público para cargar alertas
  Future<void> loadAlertsFromPrefs(SharedPreferences prefs) async {
    await _loadAlerts();
  }

  // Obtener todas las alertas activas
  List<BusAlert> getActiveAlerts() {
    return _activeAlerts.values.toList();
  }

  // Obtener número de alertas activas
  int get activeAlertsCount => _activeAlerts.length;

  bool hasAlert(int stopId, String line, String destination) {
    final key = '${stopId}_${line}_${destination}';
    return _activeAlerts.containsKey(key);
  }

  // Método público para chequear alertas inmediatamente
  Future<void> checkAlertsNow() async {
    await _checkAlerts();
  }

  Future<void> _startMonitoring() async {
    // El ForegroundService se encarga del monitoreo en segundo plano
    // Aquí solo chequeamos inmediatamente
    await _checkAlerts();
  }

  Future<void> _stopMonitoring() async {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  Future<void> _checkAlerts() async {
    if (_activeAlerts.isEmpty) return;

    final alertsByStop = <int, List<BusAlert>>{};
    for (final alert in _activeAlerts.values) {
      alertsByStop.putIfAbsent(alert.stopId, () => []).add(alert);
    }

    for (final entry in alertsByStop.entries) {
      final stopId = entry.key;
      final alerts = entry.value;
      
      try {
        final arrivals = await _busTimesService.getArrivalTimes(stopId);
        
        for (final alert in alerts) {
          // Buscar coincidencia en los arrivals
          final matchingArrival = arrivals.firstWhere(
            (arrival) => 
                arrival.line == alert.line && 
                arrival.destination == alert.destination,
            orElse: () => BusArrival(line: '', destination: '', time: ''),
          );
          
          if (matchingArrival.line.isNotEmpty) {
            final minutes = _parseMinutes(matchingArrival.time);
            bool alertUpdated = false;
            
            // Si el tiempo es -1 (>>> sin servicio), el bus ya pasó - eliminar alerta
            if (minutes < 0) {
              await removeAlert(alert.key);
              continue;
            }
            
            // Si el bus ya pasó hace más de 5 minutos o la alerta es muy antigua, eliminarla
            if (minutes > 60 || DateTime.now().difference(alert.createdAt).inMinutes > 30) {
              await removeAlert(alert.key);
              continue;
            }
            
            // Si nunca hemos notificado y el bus está llegando pronto (<=10 min)
            if (minutes <= 10 && !alert.notified5min && !alert.notified2min && !alert.notifiedArriving) {
              // Primera notificación
              await _notificationService.showBusArrivalAlert(
                stopName: alert.stopName,
                line: alert.line,
                destination: alert.destination,
                minutes: minutes,
                urgency: minutes <= 2 ? 'muy_cerca' : 'pronto',
              );
              
              if (minutes <= 2) {
                alert.notified2min = true;
                alert.notified5min = true; // Marcar ambos para no repetir
              } else {
                alert.notified5min = true;
              }
              alertUpdated = true;
            }
            // Segunda notificación a 2 minutos (si ya notificamos a 5)
            else if (minutes <= 2 && minutes > 0 && alert.notified5min && !alert.notified2min) {
              await _notificationService.showBusArrivalAlert(
                stopName: alert.stopName,
                line: alert.line,
                destination: alert.destination,
                minutes: minutes,
                urgency: 'muy_cerca',
              );
              alert.notified2min = true;
              alertUpdated = true;
            }
            // Notificación final cuando llega (1 min o menos, incluyendo <<< que se parsea como 0)
            else if (minutes <= 1 && minutes >= 0 && !alert.notifiedArriving) {
              await _notificationService.showBusArrivalAlert(
                stopName: alert.stopName,
                line: alert.line,
                destination: alert.destination,
                minutes: minutes,
                urgency: 'llegando',
                payload: 'trip_confirm',
              );
              alert.notifiedArriving = true;
              alertUpdated = true;
              
              // Guardar viaje pendiente para confirmar
              await _savePendingTrip(alert);
              
              // Notificar al stream para que la UI reaccione al instante si está abierta
              final pendingData = {
                'line': alert.line,
                'destination': alert.destination,
                'stopName': alert.stopName,
                'stopId': alert.stopId,
                'timestamp': DateTime.now().toIso8601String(),
              };
              _arrivalController.add(pendingData);
              
              // Remover alerta después de notificar llegada
              await removeAlert(alert.key);
            }
            
            // Guardar cambios si hubo actualización
            if (alertUpdated) {
              await _saveAlerts();
            }
          }
        }
      } catch (e) {
        // Error al obtener horarios, continuar con siguiente parada
      }
    }
  }

  int _parseMinutes(String time) {
    final cleanTime = time.toLowerCase().trim();
    
    // Parsear tiempo: "5 min", "En parada", "12:30", etc.
    if (cleanTime.contains('parada')) return 0;
    
    // Solo tratar como 0 si es el símbolo de llegada ("<<<" o "<") SIN números a continuación
    if ((cleanTime.contains('<<<') || cleanTime.contains('< < <') || cleanTime == '<') && !cleanTime.contains(RegExp(r'\d'))) {
      return 0;
    }
    
    // >>> significa que el bus ya pasó - devolver -1
    if (cleanTime.contains('>>>') || cleanTime.contains('> > >')) return -1;
    
    // Sin servicio
    if (cleanTime.contains('---') || cleanTime.isEmpty) return -1;
    
    // Extraer el primer número que aparezca (ignorando el < si lo tiene, ej: "< 3 min" -> 3)
    final match = RegExp(r'(\d+)').firstMatch(cleanTime);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 99;
    }
    
    // Si es hora (HH:MM), calcular diferencia
    final timeMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(cleanTime);
    if (timeMatch != null) {
      final hour = int.tryParse(timeMatch.group(1) ?? '0') ?? 0;
      final minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
      final now = DateTime.now();
      final busTime = DateTime(now.year, now.month, now.day, hour, minute);
      var diff = busTime.difference(now).inMinutes;
      
      // Si el tiempo es negativo, asumir que es para el día siguiente
      if (diff < 0) diff += 24 * 60;
      
      return diff;
    }
    
    return 99; // Desconocido
  }

  List<BusAlert> getAlertsForStop(int stopId) {
    return _activeAlerts.values
        .where((alert) => alert.stopId == stopId)
        .toList();
  }
  
  // Guardar viaje pendiente para confirmar después.
  // Encapsulado en LocalTripStorageImpl para no acoplarnos a la clave cruda.
  Future<void> _savePendingTrip(BusAlert alert) async {
    print('[BusAlertService] Guardando pending trip: ${alert.line} -> ${alert.stopName}');
    final prefs = await SharedPreferences.getInstance();
    final tripData = {
      'stopId': alert.stopId,
      'stopName': alert.stopName,
      'line': alert.line,
      'destination': alert.destination,
      'timestamp': DateTime.now().toIso8601String(),
    };
    final storage = LocalTripStorageImpl(SharedPrefsAdapter(prefs));
    final result = await storage.savePendingTrip(tripData);
    if (result.isErr) {
      await Sentry.captureException(
        result.unwrapErr(),
        withScope: (scope) {
          scope.setTag('failure_code', 'trip.save_pending_failed');
          scope.level = SentryLevel.warning;
        },
      );
    }
    print('[BusAlertService] Pending trip guardado!');
  }

  void dispose() {
    _stopMonitoring();
  }
}
