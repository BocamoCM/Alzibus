import 'dart:typed_data';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart' show AndroidNotificationChannel;

class NotificationService {
  final FlutterLocalNotificationsPlugin _notif;

  NotificationService(this._notif);

  Future<void> initialize(Function(String?)? onNotificationTap) async {
    const android = AndroidInitializationSettings('@drawable/ic_launcher_foreground');
    final initSettings = InitializationSettings(
      android: android,
    );
    await _notif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (onNotificationTap != null) {
          onNotificationTap(details.payload);
        }
      },
    );
    
    // Crear canal de notificación heads-up (nuevo id para forzar actualización)
    const androidChannel = AndroidNotificationChannel(
      'alzibus-hu',
      'Alzibus (Heads-up)',
      description: 'Notificaciones heads-up de paradas cercanas',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // Canal para alertas de bus llegando
    const alertsChannel = AndroidNotificationChannel(
      'alzibus-alerts',
      'Alertas de Bus',
      description: 'Te avisa cuando tu bus está llegando',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    final plugin = _notif
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    await plugin?.createNotificationChannel(androidChannel);
    await plugin?.createNotificationChannel(alertsChannel);
  }

  Future<void> showProximityNotification(String stopName, List<String> lines, double distance) async {
    final androidDetails = AndroidNotificationDetails(
      'alzibus-hu',
      'Alzibus (Heads-up)',
      channelDescription: 'Notificaciones heads-up de paradas cercanas',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      ticker: 'Parada cercana',
      styleInformation: const BigTextStyleInformation(''),
      fullScreenIntent: true,
      category: AndroidNotificationCategory.navigation,
      visibility: NotificationVisibility.public,
    );
    final details = NotificationDetails(android: androidDetails);
    
    await _notif.show(
      0,
      '🚍 Parada cercana',
      '$stopName — ${lines.join(', ')} (${distance.toStringAsFixed(0)}m)',
      details,
    );
  }

  Future<void> showBusArrivalAlert({
    required String stopName,
    required String line,
    required String destination,
    required int minutes,
    String urgency = 'pronto', // 'pronto', 'muy_cerca', 'llegando'
  }) async {
    // Configurar mensaje y vibración según urgencia
    String title;
    Int64List vibrationPattern;
    
    switch (urgency) {
      case 'muy_cerca':
        title = '⚠️ ¡Bus muy cerca!';
        vibrationPattern = Int64List.fromList([0, 800, 200, 800, 200, 800]);
        break;
      case 'llegando':
        title = '🔔 ¡BUS LLEGANDO AHORA!';
        vibrationPattern = Int64List.fromList([0, 500, 200, 500, 200, 500, 200, 500]);
        break;
      default: // 'pronto'
        title = '🚌 Bus llegando pronto';
        vibrationPattern = Int64List.fromList([0, 1000, 300, 1000]);
    }
    
    final androidDetails = AndroidNotificationDetails(
      'alzibus-alerts',
      'Alertas de Bus',
      channelDescription: 'Te avisa cuando tu bus está llegando',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      ticker: 'Bus llegando',
      styleInformation: const BigTextStyleInformation(''),
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      enableLights: true,
      ledColor: const Color.fromARGB(255, 255, 0, 0),
      ledOnMs: 1000,
      ledOffMs: 500,
    );
    
    final details = NotificationDetails(android: androidDetails);
    
    final timeText = minutes == 0 
        ? '¡Ya está en parada!' 
        : minutes == 1 
            ? '¡Llega en 1 minuto!' 
            : 'Llega en $minutes minutos';

    await _notif.show(
      '${line}_${destination}_$urgency'.hashCode,
      '$title - Línea $line',
      '$stopName → $destination\n$timeText',
      details,
    );
  }
}
