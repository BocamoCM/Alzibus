import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart' show Color;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

class NotificationService {
  final FlutterLocalNotificationsPlugin _notif;

  NotificationService(this._notif);

  Future<void> initialize(Function(String?)? onNotificationTap) async {
    const android = AndroidInitializationSettings('ic_notification');
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
      'Alzitrans (Proximidad)',
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

    // Canal para avisos y mensajes del admin
    const noticesChannel = AndroidNotificationChannel(
      'alzibus-notices',
      'Avisos y Mensajes',
      description:
          'Notificaciones sobre nuevos avisos y respuestas del administrador',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // Canal para los avisos proactivos de "tu bus de siempre" (rutinas).
    const habitsChannel = AndroidNotificationChannel(
      'alzibus-habits',
      'Rutinas',
      description: 'Avisos de tus trayectos habituales',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    final plugin = _notif.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await plugin?.createNotificationChannel(androidChannel);
    await plugin?.createNotificationChannel(alertsChannel);
    await plugin?.createNotificationChannel(noticesChannel);
    await plugin?.createNotificationChannel(habitsChannel);

    _ensureTz();
  }

  static bool _tzReady = false;

  /// Inicializa la base de datos de zonas horarias y fija Europe/Madrid.
  /// Idempotente y sin depender de [initialize] (que lleva el handler de
  /// taps), para poder programar avisos desde cualquier sitio.
  void _ensureTz() {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Madrid'));
    } catch (_) {
      // Sin la BD de zonas quedaría en UTC: el aviso se desfasaría pero
      // no crashea.
    }
    _tzReady = true;
  }

  /// Programa un aviso semanal recurrente (mismo día de la semana + hora)
  /// para un trayecto habitual. Usa modo inexacto para NO requerir el permiso
  /// de alarmas exactas en Android 14+. Se vuelve a programar al abrir la app
  /// (los alarms se pierden al reiniciar el móvil).
  Future<void> scheduleHabitReminder({
    required int id,
    required int weekday,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    _ensureTz();
    final scheduled = _nextInstanceOfWeekdayTime(weekday, hour, minute);
    final androidDetails = AndroidNotificationDetails(
      'alzibus-habits',
      'Rutinas',
      channelDescription: 'Avisos de tus trayectos habituales',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: const BigTextStyleInformation(''),
      color: const Color(0xFF4A1D3D),
      icon: 'ic_notification',
    );
    await _notif.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> cancelHabitReminder(int id) => _notif.cancel(id);

  tz.TZDateTime _nextInstanceOfWeekdayTime(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> showProximityNotification(
      String stopName, List<String> lines, double distance) async {
    final androidDetails = AndroidNotificationDetails(
      'alzibus-hu',
      'Alzitrans (Proximidad)',
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
      color: const Color(0xFF4A1D3D), // Color granate Alzitrans
      icon: 'ic_notification',
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
    String? payload,
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
        vibrationPattern =
            Int64List.fromList([0, 500, 200, 500, 200, 500, 200, 500]);
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
      color: const Color(0xFF4A1D3D), // Color granate Alzitrans
      icon: 'ic_notification',
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
      payload: payload,
    );
  }

  Future<void> showNoticeNotification(String title, String body) async {
    final androidDetails = AndroidNotificationDetails(
      'alzibus-notices',
      'Avisos y Mensajes',
      channelDescription:
          'Notificaciones sobre nuevos avisos y respuestas del administrador',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 400, 200, 400]),
      ticker: 'Nuevo Aviso',
      styleInformation: BigTextStyleInformation(body),
      color: const Color(0xFF4A1D3D), // Color granate Alzitrans
      icon: 'ic_notification',
    );
    final details = NotificationDetails(android: androidDetails);

    await _notif.show(
      title.hashCode, // Usar un hash simple
      title,
      body,
      details,
    );
  }
}
