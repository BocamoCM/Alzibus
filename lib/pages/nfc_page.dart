import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../theme/app_theme.dart';
import '../models/bus_card.dart';

/// Claves Mifare para tarjetas de bus de Alzira
/// Extraídas de los dumps de las tarjetas reales
class BusCardKeys {
  // Claves Key A por sector (extraídas de sector trailers)
  static final Map<int, Uint8List> keyA = {
    0: Uint8List.fromList([0xBC, 0x93, 0x33, 0xB1, 0xBB, 0x6E]),  // Block 3
    1: Uint8List.fromList([0xDF, 0xED, 0x7C, 0x26, 0xBF, 0x1B]),  // Block 7 - Contiene estado actual
    2: Uint8List.fromList([0x17, 0x5B, 0x77, 0xCD, 0x00, 0x97]),  // Block 11
    3: Uint8List.fromList([0xE4, 0xBC, 0xDF, 0x37, 0x24, 0x03]),  // Block 15
    4: Uint8List.fromList([0xE4, 0x74, 0xDF, 0x44, 0x8D, 0x37]),  // Block 19
    5: Uint8List.fromList([0x39, 0x8E, 0xA4, 0xFE, 0x52, 0x06]),  // Block 23 - Historial
    6: Uint8List.fromList([0xF2, 0x0C, 0x09, 0x4B, 0xDB, 0x31]),  // Block 27
    7: Uint8List.fromList([0x1C, 0x93, 0x8B, 0xA7, 0xE7, 0x0E]),  // Block 31
  };
  
  // Clave por defecto (fallback)
  static final Uint8List defaultKey = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
}

class NfcPage extends StatefulWidget {
  const NfcPage({super.key});

  @override
  State<NfcPage> createState() => _NfcPageState();
}

class _NfcPageState extends State<NfcPage> with SingleTickerProviderStateMixin {
  String _status = 'Acerca tu tarjeta para leer el saldo';
  bool _scanning = false;
  BusCard? _cardData;
  bool _nfcAvailable = true;
  bool _lowBalanceWarningsEnabled = true;
  int _lowBalanceThreshold = 5;
  final FlutterLocalNotificationsPlugin _notif = FlutterLocalNotificationsPlugin();
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initNotifications();
    _loadPreferences();
    _checkNfcAvailability();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkNfcAvailability() async {
    final isAvailable = await NfcManager.instance.isAvailable();
    setState(() {
      _nfcAvailable = isAvailable;
      if (!isAvailable) {
        _status = 'NFC no disponible en este dispositivo';
      }
    });
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
    if (_lowBalanceWarningsEnabled && trips > 0 && trips <= _lowBalanceThreshold) {
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
    if (!_nfcAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NFC no disponible')),
      );
      return;
    }

    setState(() {
      _scanning = true;
      _status = 'Acerca tu tarjeta al teléfono...';
      _cardData = null;
    });

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        onDiscovered: (NfcTag tag) async {
          await _handleTagDiscovered(tag);
        },
      );
    } catch (e) {
      debugPrint('Error starting NFC session: $e');
      setState(() {
        _status = 'Error al iniciar escaneo NFC';
        _scanning = false;
      });
    }
  }

  Future<void> _handleTagDiscovered(NfcTag tag) async {
    try {
      String? uid;
      
      // Intentar obtener UID de NfcA (común en Mifare)
      final nfca = NfcAAndroid.from(tag);
      if (nfca != null) {
        uid = nfca.tag.id.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
      }
      
      // Si no, intentar IsoDep
      if (uid == null) {
        final isodep = IsoDepAndroid.from(tag);
        if (isodep != null) {
          uid = isodep.tag.id.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
        }
      }
      
      // Intentar obtener la tarjeta Android base
      final androidTag = NfcTagAndroid.from(tag);
      if (androidTag != null && uid == null) {
        uid = androidTag.id.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
      }
      
      // Intentar Mifare Classic - usando claves reales de las tarjetas de bus
      final mifareClassic = MifareClassicAndroid.from(tag);
      BusCard? cardData;
      
      if (mifareClassic != null) {
        if (uid == null) {
          uid = mifareClassic.tag.id.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
        }
        
        // Claves Mifare de las tarjetas de bus de Alzira
        // Usamos las claves específicas del sector 1 (blocks 4-7)
        final keysToTry = [
          BusCardKeys.keyA[1]!, // Key A del Sector 1 (primaria)
          BusCardKeys.keyA[0]!, // Key A del Sector 0 (alternativa)
          BusCardKeys.defaultKey, // Clave por defecto (último recurso)
        ];
        
        // Intentar leer bloques con autenticación
        try {
          bool authenticated = false;
          
          // Intentar cada clave hasta que una funcione
          for (final key in keysToTry) {
            try {
              authenticated = await mifareClassic.authenticateSectorWithKeyA(
                sectorIndex: 1,
                key: key,
              );
              if (authenticated) {
                debugPrint('Autenticación exitosa con clave: ${key.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
                break;
              }
            } catch (e) {
              debugPrint('Clave fallida: ${key.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
              // Probar siguiente clave
            }
            
            // También probar con KeyB
            if (!authenticated) {
              try {
                authenticated = await mifareClassic.authenticateSectorWithKeyB(
                  sectorIndex: 1,
                  key: key,
                );
                if (authenticated) {
                  debugPrint('Autenticación exitosa con KeyB: ${key.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
                  break;
                }
              } catch (e) {
                // Probar siguiente
              }
            }
          }
          
          if (authenticated) {
            // Leer block 5 (estado actual)
            final block5 = await mifareClassic.readBlock(blockIndex: 5);
            debugPrint('Block 5 leído: ${block5.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
            
            // Parsear datos según estructura analizada:
            // Byte 1: tipo de tarjeta
            // Bytes 2-3: saldo en céntimos (big-endian)
            // Byte 8: contador de viajes
            final balance = (block5[2] << 8) | block5[3];
            final trips = block5[8];
            final cardType = block5[1];
            
            cardData = BusCard(
              uid: uid,
              balance: balance,
              trips: trips,
              cardType: cardType,
            );
            
            setState(() {
              _status = 'Tarjeta leída correctamente';
              _cardData = cardData;
              _scanning = false;
            });
            
            await _checkLowBalance(trips);
          } else {
            // No se pudo autenticar
            setState(() {
              _status = 'No se pudo autenticar la tarjeta';
              _cardData = BusCard(uid: uid!, balance: 0, trips: 0, cardType: 0);
              _scanning = false;
            });
          }
        } catch (e) {
          debugPrint('Mifare auth error: $e');
          setState(() {
            _status = 'Error de autenticación Mifare';
            _cardData = BusCard(uid: uid ?? 'Desconocido', balance: 0, trips: 0, cardType: 0);
            _scanning = false;
          });
        }
      } else {
        // No es Mifare Classic
        uid ??= 'Desconocido';
        setState(() {
          _status = 'Tarjeta detectada (no es Mifare Classic)';
          _cardData = BusCard(uid: uid!, balance: 0, trips: 0, cardType: 0);
          _scanning = false;
        });
      }
      
      // Mostrar diálogo informativo
      if (mounted && mifareClassic == null) {
        _showCardInfoDialog(uid);
      }
      
      await NfcManager.instance.stopSession();
    } catch (e) {
      debugPrint('Error reading tag: $e');
      setState(() {
        _status = 'Error al leer la tarjeta: ${e.toString().split('\n').first}';
        _scanning = false;
      });
      await NfcManager.instance.stopSession();
    }
  }

  void _showCardInfoDialog(String uid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.nfc, color: AlzibusColors.burgundy),
            const SizedBox(width: 8),
            const Text('Tarjeta detectada'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('UID: $uid'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Las tarjetas Mifare Classic 1K requieren autenticación especial para leer el saldo. La mayoría de móviles Android no pueden leerlas sin hardware especializado.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
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
    );
  }

  void _stopScan() {
    NfcManager.instance.stopSession();
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

  void _showFlipperDumpInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.analytics, color: AlzibusColors.burgundy),
            const SizedBox(width: 8),
            const Text('Información de tarjetas'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tarjetas analizadas:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildCardInfo('Bus1.nfc', 'Antes de usar', '0.96€', '1 viaje'),
              const Divider(),
              _buildCardInfo('Bus2.nfc', 'Después de usar', '4.50€', '27 viajes'),
              const Divider(),
              _buildCardInfo('BusJP.nfc', 'Bono ilimitado', 'Ilimitado', '--'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Estructura detectada:\n'
                  '• Bloque 5: Estado actual\n'
                  '• Bytes 2-3: Saldo en céntimos\n'
                  '• Byte 8: Contador de viajes\n'
                  '• Bloques 20-26: Historial',
                  style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildCardInfo(String name, String desc, String balance, String trips) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.credit_card, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(balance, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(trips, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trips = _cardData?.trips;
    final balance = _cardData?.balanceFormatted;
    final isLowBalance = trips != null && trips > 0 && trips <= _lowBalanceThreshold;

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Tarjeta visual
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
                    // Patrón decorativo
                    Positioned(
                      right: -30,
                      bottom: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    // Info de la tarjeta
                    Positioned(
                      top: 20,
                      left: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.credit_card, color: Colors.white.withOpacity(0.9), size: 40),
                          const SizedBox(height: 8),
                          const Text(
                            'Tarjeta Alzibus',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_cardData != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'UID: ${_cardData!.uid}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Saldo y viajes
                    Positioned(
                      bottom: 20,
                      left: 20,
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Saldo',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                balance ?? '--',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 40),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Viajes',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                trips != null ? '$trips' : '--',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Icono NFC
                    Positioned(
                      top: 20,
                      right: 20,
                      child: _scanning
                          ? AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) => Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Icon(
                                  Icons.nfc,
                                  color: Colors.white.withOpacity(0.9),
                                  size: 50,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.nfc,
                              color: Colors.white.withOpacity(0.9),
                              size: 50,
                            ),
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
                  color: isLowBalance ? Colors.orange : Colors.grey[700],
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
                    onPressed: _nfcAvailable ? _startScan : null,
                    icon: const Icon(Icons.nfc, size: 28),
                    label: Text(
                      _nfcAvailable ? 'Escanear tarjeta' : 'NFC no disponible',
                      style: const TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AlzibusColors.burgundy,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
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
              // Info adicional
              if (_cardData != null && isLowBalance) ...[
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber, color: Colors.orange),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            '¡Recarga tu tarjeta pronto!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Botón de info de dumps
              OutlinedButton.icon(
                onPressed: _showFlipperDumpInfo,
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Ver análisis de tarjetas'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AlzibusColors.burgundy,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showSettingsDialog,
        backgroundColor: AlzibusColors.burgundy,
        foregroundColor: Colors.white,
        tooltip: 'Ajustes de advertencias',
        child: const Icon(Icons.settings),
      ),
    );
  }
}
