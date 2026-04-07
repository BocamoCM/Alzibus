import 'package:flutter/material.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../providers/high_visibility_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/ad_banner_widget.dart';
import '../services/ad_service.dart';
import '../core/providers/ad_provider.dart';
import '../core/providers/locale_provider.dart';
import '../constants/app_config.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/providers/gamification_provider.dart';
import '../services/gamification_service.dart';
import 'support_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  final bool notificationsEnabled;
  final double notificationDistance;
  final int notificationCooldown;
  final bool showSimulatedBuses;
  final bool autoRefreshTimes;
  final bool vibrationEnabled;
  final bool ttsEnabled;
  final Function(bool) onNotificationsChanged;
  final Function(double) onDistanceChanged;
  final Function(int) onCooldownChanged;
  final Function(bool) onShowSimulatedBusesChanged;
  final Function(bool) onAutoRefreshTimesChanged;
  final Function(bool) onVibrationChanged;
  final Function(bool) onTtsChanged;

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
  });

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {

  late bool _notificationsEnabled;
  late double _notificationDistance;
  late int _notificationCooldown;
  late bool _showSimulatedBuses;
  late bool _autoRefreshTimes;
  late bool _vibrationEnabled;
  late bool _ttsEnabled;
  late bool _highVisibility;

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
    _highVisibility = ref.read(highVisibilityProvider);
  }


  Widget _languageTile({
    required String name,
    required Locale locale,
  }) {
    final activeLocale = Localizations.localeOf(context);
    final isSelected = activeLocale.languageCode == locale.languageCode;
    return ListTile(
      leading: const Icon(Icons.language, color: AlzitransColors.burgundy),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AlzitransColors.burgundy)
          : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () {
        ref.read(localeProvider.notifier).setLocale(locale);
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
        Text(l.language,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AlzitransColors.burgundy)),
        const SizedBox(height: 12),
        _languageTile(name: 'Español', locale: const Locale('es')),
        _languageTile(name: 'English', locale: const Locale('en')),
        _languageTile(name: 'Valencià', locale: const Locale('ca')),
        
        const Divider(),
        Text(l.information.toUpperCase(),
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
        SwitchListTile(
          title: Text(l.highVisibilityMode),
          subtitle: Text(l.highVisibilitySubtitle),
          value: _highVisibility,
          onChanged: (val) {
            setState(() => _highVisibility = val);
            ref.read(highVisibilityProvider.notifier).toggle(val);
          },
          secondary: const Icon(Icons.visibility),
        ),
        const Divider(),
        Text(l.privacyAndPermissions,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AlzitransColors.burgundy)),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.location_on, color: AlzitransColors.burgundy),
          title: Text(l.backgroundAlerts),
          subtitle: Text(l.backgroundAlertsSubtitle),
          trailing: ElevatedButton(
            onPressed: () async {
              if (await Permission.locationAlways.isGranted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.permissionActivated))
                );
              } else {
                // Limpiar el flag de bloqueo para que la app pueda volver a pedirlo
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('background_location_disabled');
                
                // Abrir ajustes para que sea el usuario el que lo active
                await openAppSettings();
              }
            },
            child: Text(l.configure),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip, color: AlzitransColors.burgundy),
          title: Text(l.privacyPolicy),
          subtitle: Text(l.privacyPolicySubtitle),
          onTap: () => launchUrl(Uri.parse(AppConfig.privacyPolicyUrl)),
          trailing: const Icon(Icons.open_in_new, size: 20),
        ),
        const Divider(),
        Text(l.helpAndSupport.toUpperCase(),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AlzitransColors.burgundy)),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.help_outline, color: AlzitransColors.burgundy),
          title: Text(l.helpAndSupport),
          subtitle: Text(l.helpAndSupportSubtitle),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupportPage()),
            );
          },
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        ),
        
        const SizedBox(height: 12),
        if (AppConfig.showAds)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60, maxHeight: 70),
              child: AdBannerWidget(
                adUnitId: AppConfig.settingsBannerAdId,
              ),
            ),
          ),
        const SizedBox(height: 48),
      ],
    ),
    );
  }

}
