import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../services/foreground_service.dart';
import '../theme/app_theme.dart';
import '../providers/elderly_mode_provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import '../constants/app_config.dart';

class SettingsPage extends StatefulWidget {
  final bool notificationsEnabled;
  final double notificationDistance;
  final int notificationCooldown;
  final bool showSimulatedBuses;
  final bool autoRefreshTimes;
  final bool vibrationEnabled;
  final Function(bool) onNotificationsChanged;
  final Function(double) onDistanceChanged;
  final Function(int) onCooldownChanged;
  final Function(bool) onShowSimulatedBusesChanged;
  final Function(bool) onAutoRefreshTimesChanged;
  final Function(bool) onVibrationChanged;
  final bool ttsEnabled;
  final Function(Locale) onLocaleChanged;
  final Function(bool) onTtsChanged;
  final Locale currentLocale;

  const SettingsPage({
    super.key,
    required this.notificationsEnabled,
    required this.notificationDistance,
    required this.notificationCooldown,
    required this.showSimulatedBuses,
    required this.autoRefreshTimes,
    required this.vibrationEnabled,
    required this.ttsEnabled,
    required this.onNotificationsChanged,
    required this.onDistanceChanged,
    required this.onCooldownChanged,
    required this.onShowSimulatedBusesChanged,
    required this.onAutoRefreshTimesChanged,
    required this.onVibrationChanged,
    required this.onTtsChanged,
    required this.onLocaleChanged,
    required this.currentLocale,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _lastBackgroundCheck = 'Nunca';
  String _lastBusCheck = 'Sin datos';
  int _alertsCount = 0;
  bool _serviceRunning = false;
  String _appVersion = '';
  String _buildNumber = '';
  
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  late bool _notificationsEnabled;
  late double _notificationDistance;
  late int _notificationCooldown;
  late bool _showSimulatedBuses;
  late bool _autoRefreshTimes;
  late bool _vibrationEnabled;
  late bool _ttsEnabled;
  late Locale _currentLocale;
  late bool _elderlyMode;

  @override
  void initState() {
    super.initState();
    _notificationsEnabled = widget.notificationsEnabled;
    _notificationDistance = widget.notificationDistance;
    _notificationCooldown = widget.notificationCooldown;
    _showSimulatedBuses = widget.showSimulatedBuses;
    _autoRefreshTimes = widget.autoRefreshTimes;
    _vibrationEnabled = widget.vibrationEnabled;
    _ttsEnabled = widget.ttsEnabled;
    _currentLocale = widget.currentLocale;
    _elderlyMode = elderlyModeNotifier.enabled;
    
    _loadDebugInfo();
    _loadAppVersion();
    _initBannerAd();
  }

  void _initBannerAd() {
    if (!AppConfig.showAds) return;

    _bannerAd = AdService.instance.createBannerAd(
      onAdLoaded: (ad) {
        setState(() => _isBannerAdLoaded = true);
      },
      onAdFailedToLoad: (ad, error) {
        setState(() => _isBannerAdLoaded = false);
      },
    )..load();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  Future<void> _loadDebugInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getString('last_foreground_check') ?? prefs.getString('last_background_check');
    final lastBus = prefs.getString('last_bus_check') ?? 'Sin datos';
    final alertsJson = prefs.getString('bus_alerts');
    final isRunning = await ForegroundService.isRunning();
    
    setState(() {
      _serviceRunning = isRunning;
      _lastBusCheck = lastBus;
      if (lastCheck != null) {
        final dt = DateTime.tryParse(lastCheck);
        if (dt != null) {
          final diff = DateTime.now().difference(dt);
          if (diff.inMinutes < 1) {
            _lastBackgroundCheck = 'Hace ${diff.inSeconds}s';
          } else if (diff.inMinutes < 60) {
            _lastBackgroundCheck = 'Hace ${diff.inMinutes} min';
          } else {
            _lastBackgroundCheck = 'Hace ${diff.inHours}h ${diff.inMinutes % 60}min';
          }
        }
      }
      if (alertsJson != null && alertsJson.isNotEmpty) {
        try {
          final list = alertsJson.split('},{').length;
          _alertsCount = alertsJson == '[]' ? 0 : list;
        } catch (_) {}
      }
    });
  }

  Future<void> _testNotification() async {
    final notif = FlutterLocalNotificationsPlugin();
    
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_launcher_foreground'),
    );
    await notif.initialize(initSettings);
    
    // Crear canal
    final androidPlugin = notif.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    const alertsChannel = AndroidNotificationChannel(
      'alzibus_alerts',
      'Alertas de Bus',
      description: 'Te avisa cuando tu bus está llegando',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await androidPlugin?.createNotificationChannel(alertsChannel);
    
    // Mostrar notificación de prueba
    const androidDetails = AndroidNotificationDetails(
      'alzibus_alerts',
      'Alertas de Bus',
      channelDescription: 'Te avisa cuando tu bus está llegando',
      importance: Importance.max,
      priority: Priority.max,
      ticker: 'Prueba',
      icon: '@drawable/ic_launcher_foreground',
      playSound: true,
      enableVibration: true,
    );
    
    await notif.show(
      999999,
      '🧪 Notificación de prueba',
      '¡Las notificaciones funcionan correctamente!',
      const NotificationDetails(android: androidDetails),
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Notificación de prueba enviada'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _languageTile({
    required String flag,
    required String name,
    required Locale locale,
  }) {
    final isSelected = _currentLocale.languageCode == locale.languageCode;
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AlzitransColors.burgundy)
          : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('app_locale', locale.languageCode);
        setState(() => _currentLocale = locale);
        widget.onLocaleChanged(locale);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.tabSettings)),
      body: ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(l.notifications,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SwitchListTile(
          title: Text(l.activateNotifications),
          subtitle: Text(l.notificationsSubtitle),
          value: _notificationsEnabled,
          onChanged: (val) {
            setState(() => _notificationsEnabled = val);
            widget.onNotificationsChanged(val);
          },
        ),
        const Divider(),
        ListTile(
          title: Text(l.alertDistance),
          subtitle: Text('${_notificationDistance.toInt()} m'),
        ),
        Slider(
          value: _notificationDistance,
          min: 20,
          max: 200,
          divisions: 18,
          label: '${_notificationDistance.toInt()}m',
          onChanged: _notificationsEnabled ? (val) {
            setState(() => _notificationDistance = val);
            widget.onDistanceChanged(val);
          } : null,
        ),
        const Divider(),
        ListTile(
          title: Text(l.timeBetweenNotifications),
          subtitle: Text('${_notificationCooldown} min'),
        ),
        Slider(
          value: _notificationCooldown.toDouble(),
          min: 1,
          max: 30,
          divisions: 29,
          label: '${_notificationCooldown} min',
          onChanged: _notificationsEnabled
              ? (val) {
                  setState(() => _notificationCooldown = val.toInt());
                  widget.onCooldownChanged(val.toInt());
                }
              : null,
        ),
        SwitchListTile(
          title: Text(l.vibration),
          subtitle: Text(l.vibrationSubtitle),
          value: _vibrationEnabled,
          onChanged: _notificationsEnabled ? (val) {
            setState(() => _vibrationEnabled = val);
            widget.onVibrationChanged(val);
          } : null,
          secondary: const Icon(Icons.vibration),
        ),
        
        const Divider(),
        Text(l.information.toUpperCase(), // Usando una etiqueta existente o similar para agrupar
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AlzitransColors.burgundy)),
        const SizedBox(height: 8),
        SwitchListTile(
          title: Text(l.accessibilityVoice),
          subtitle: Text(l.accessibilityVoiceSubtitle),
          value: _ttsEnabled,
          onChanged: (val) {
            setState(() => _ttsEnabled = val);
            widget.onTtsChanged(val);
          },
          secondary: const Icon(Icons.record_voice_over),
        ),

        const SizedBox(height: 4),

        // --- MODO PERSONAS MAYORES ---
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AlzitransColors.burgundy.withOpacity(0.08), AlzitransColors.wine.withOpacity(0.05)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _elderlyMode ? AlzitransColors.burgundy.withOpacity(0.4) : Colors.transparent),
          ),
          child: SwitchListTile(
            title: const Text(
              'Modo Personas Mayores 👵🏼',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Aumenta el tamaño de textos y botones en toda la app'),
            value: _elderlyMode,
            onChanged: (val) {
              setState(() => _elderlyMode = val);
              elderlyModeNotifier.toggle(val);
            },
            secondary: Icon(
              Icons.accessibility_new,
              color: _elderlyMode ? AlzitransColors.burgundy : Colors.grey,
              size: _elderlyMode ? 32 : 24,
            ),
          ),
        ),
        
        const SizedBox(height: 24),

        // Idioma
        Text(l.language,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                _languageTile(flag: '🇪🇸', name: 'Español', locale: const Locale('es')),
                _languageTile(flag: '🏳️', name: 'Valencià', locale: const Locale('ca')),
                _languageTile(flag: '🇬🇧', name: 'English', locale: const Locale('en')),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Mapa
        Text(l.map,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SwitchListTile(
          title: Text(l.showSimulatedBuses),
          subtitle: Text(l.showSimulatedBusesSubtitle),
          value: _showSimulatedBuses,
          onChanged: (val) {
            setState(() => _showSimulatedBuses = val);
            widget.onShowSimulatedBusesChanged(val);
          },
          secondary: const Icon(Icons.directions_bus),
        ),
        SwitchListTile(
          title: Text(l.autoRefreshTimes),
          subtitle: Text(l.autoRefreshTimesSubtitle),
          value: _autoRefreshTimes,
          onChanged: (val) {
            setState(() => _autoRefreshTimes = val);
            widget.onAutoRefreshTimesChanged(val);
          },
          secondary: const Icon(Icons.refresh),
        ),
        
        const SizedBox(height: 24),

        const SizedBox(height: 24),
        Text(l.information,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.directions_bus, color: AlzitransColors.burgundy, size: 28),
                    const SizedBox(width: 12),
                    const Text('Alzibus',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AlzitransColors.burgundy.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'v$_appVersion${_buildNumber.isNotEmpty && _buildNumber != '1' ? '+$_buildNumber' : ''}',
                        style: const TextStyle(
                          color: AlzitransColors.burgundy,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(l.appDescription,
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        const SizedBox(height: 16),
        // Instrucciones para Samsung/MIUI
        Card(
          color: Colors.orange[50],
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Samsung / Xiaomi', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Si las notificaciones no funcionan bien:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                const Text('• Samsung: Ajustes → Aplicaciones → Alzibus → Batería → Sin restricciones', style: TextStyle(fontSize: 12)),
                const Text('• Xiaomi: Ajustes → Apps → Alzibus → Autostart → Activar', style: TextStyle(fontSize: 12)),
                const Text('• Xiaomi: Seguridad → Batería → Sin restricciones para Alzibus', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        
        // --- ANUNCIO BANNER ---
        if (AppConfig.showAds && _bannerAd != null && _isBannerAdLoaded)
          Container(
            alignment: Alignment.center,
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
          
        const SizedBox(height: 16),
      ],
    ),   // body: ListView
  );   // Scaffold
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
}
