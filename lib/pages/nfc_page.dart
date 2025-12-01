import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../theme/app_theme.dart';

class NfcPage extends StatefulWidget {
  const NfcPage({super.key});

  @override
  State<NfcPage> createState() => _NfcPageState();
}

class _NfcPageState extends State<NfcPage> {
  String _status = 'Acerca tu tarjeta para leer el saldo';
  bool _scanning = false;
  int? _remainingTrips;
  bool _lowBalanceWarningsEnabled = true;
  int _lowBalanceThreshold = 5;
  final FlutterLocalNotificationsPlugin _notif = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _loadPreferences();
  }

  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@drawable/ic_launcher_foreground');
    const initSettings = InitializationSettings(android: android);
    await _notif.initialize(initSettings);
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lowBalanceWarningsEnabled = prefs.getBool('low_balance_warnings') ?? true;
      _lowBalanceThreshold = prefs.getInt('low_balance_threshold') ?? 5;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('low_balance_warnings', _lowBalanceWarningsEnabled);
    await prefs.setInt('low_balance_threshold', _lowBalanceThreshold);
  }

  Future<void> _checkLowBalance(int trips) async {
    if (_lowBalanceWarningsEnabled && trips <= _lowBalanceThreshold) {
      final androidDetails = AndroidNotificationDetails(
        'alzibus-hu',
        'Alzibus (Heads-up) - Saldo',
        channelDescription: 'Avisos heads-up de saldo bajo en tarjeta',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 300, 200, 300, 200, 300]),
        ticker: 'Saldo bajo',
        styleInformation: const BigTextStyleInformation(''),
        fullScreenIntent: true,
        category: AndroidNotificationCategory.status,
        visibility: NotificationVisibility.public,
      );
      final details = NotificationDetails(android: androidDetails);
      
      // Vibrar el dispositivo
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(pattern: [0, 300, 200, 300, 200, 300]);
      }
      
      await _notif.show(
        999,
        '⚠️ Saldo bajo en tu tarjeta',
        'Te quedan solo $trips viajes. Recarga pronto tu tarjeta.',
        details,
      );
    }
  }

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _status = 'Acerca tu tarjeta al teléfono...';
      _remainingTrips = null;
    });

    try {
      final availability = await FlutterNfcKit.nfcAvailability;
      if (availability != NFCAvailability.available) {
        setState(() {
          _status = 'NFC no disponible en este dispositivo';
          _scanning = false;
        });
        return;
      }

      await FlutterNfcKit.poll(timeout: const Duration(seconds: 20));
      
      // Simulación de lectura de viajes (en la implementación real leerías los sectores MIFARE)
      // Por ahora generamos un número aleatorio entre 0 y 20 para demostración
      final simulatedTrips = DateTime.now().second % 21;
      
      setState(() {
        _remainingTrips = simulatedTrips;
        _status = 'Tarjeta leída correctamente';
        _scanning = false;
      });

      await _checkLowBalance(simulatedTrips);
      await FlutterNfcKit.finish();
    } catch (e) {
      setState(() {
        _status = 'Error al leer la tarjeta';
        _scanning = false;
      });
      await FlutterNfcKit.finish();
    }
  }

  void _stopScan() {
    FlutterNfcKit.finish();
    setState(() {
      _scanning = false;
      _status = 'Escaneo cancelado';
    });
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajustes de advertencias'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Activar advertencias'),
                subtitle: const Text('Notificar cuando el saldo sea bajo'),
                value: _lowBalanceWarningsEnabled,
                onChanged: (value) {
                  setDialogState(() => _lowBalanceWarningsEnabled = value);
                  setState(() => _lowBalanceWarningsEnabled = value);
                  _savePreferences();
                },
              ),
              const Divider(),
              ListTile(
                title: const Text('Avisar cuando queden'),
                subtitle: Text('$_lowBalanceThreshold viajes o menos'),
              ),
              Slider(
                value: _lowBalanceThreshold.toDouble(),
                min: 1,
                max: 20,
                divisions: 19,
                label: '$_lowBalanceThreshold viajes',
                onChanged: _lowBalanceWarningsEnabled
                    ? (value) {
                        setDialogState(() => _lowBalanceThreshold = value.toInt());
                        setState(() => _lowBalanceThreshold = value.toInt());
                        _savePreferences();
                      }
                    : null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Imagen de tarjeta
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  gradient: AlzibusColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 20,
                      left: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.credit_card, color: Colors.white, size: 40),
                          SizedBox(height: 8),
                          Text(
                            'Tarjeta Alzibus',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Viajes restantes',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _remainingTrips != null ? '$_remainingTrips' : '--',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Positioned(
                      top: 20,
                      right: 20,
                      child: Icon(Icons.nfc, color: Colors.white, size: 50),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Estado
              Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: _remainingTrips != null && _remainingTrips! <= _lowBalanceThreshold
                      ? Colors.orange
                      : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              // Botón de escaneo
              if (!_scanning)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _startScan,
                    icon: const Icon(Icons.nfc, size: 28),
                    label: const Text(
                      'Escanear tarjeta',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AlzibusColors.burgundy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _stopScan,
                      child: const Text('Cancelar'),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              // Información adicional
              if (_remainingTrips != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              _remainingTrips! <= _lowBalanceThreshold
                                  ? Icons.warning_amber
                                  : Icons.check_circle,
                              color: _remainingTrips! <= _lowBalanceThreshold
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _remainingTrips! <= _lowBalanceThreshold
                                    ? '¡Recarga tu tarjeta pronto!'
                                    : 'Tu saldo es suficiente',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text(
                          'Nota: Esta es una lectura simulada. La lectura real de sectores MIFARE Classic 1K requiere implementación nativa con autenticación de claves.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showSettingsDialog,
        backgroundColor: AlzibusColors.burgundy,
        foregroundColor: Colors.white,
        child: const Icon(Icons.settings),
        tooltip: 'Ajustes de advertencias',
      ),
    );
  }
}
