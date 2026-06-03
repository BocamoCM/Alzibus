import 'package:flutter/material.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/router/app_router.dart';
import '../core/providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../screens/trip_history_screen.dart';
import '../screens/feedback_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_config.dart';
import '../widgets/ad_banner_widget.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart' if (dart.library.js_util) 'package:flutter/widgets.dart';
import '../widgets/ad_ui_factory.dart';
import '../services/ad_service.dart';
import '../core/providers/ad_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/game_currency_provider.dart';
import '../models/albus_skin.dart';

/// Pantalla de perfil del usuario: muestra datos personales y estadísticas de viajes.
class ProfileScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSettingsTap;
  const ProfileScreen({super.key, this.onSettingsTap});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  AuthService get _auth => ref.read(authServiceProvider);
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    _token = await _auth.getToken();
    if (_token != null) {
      _profile = await _auth.getProfile(_token!);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.profile),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProfile,
            tooltip: l.update,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? _buildError(l)
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildAvatar(theme),
                      const SizedBox(height: 24),
                      _buildStatsCards(theme, l),
                      const SizedBox(height: 24),
                      _buildInfoCard(theme, l),
                      const SizedBox(height: 16),
                      _buildActionsCard(theme, l),
                      // Sección debug solo visible para el autor del TFC.
                      // Email hardcodeado para que solo aparezca en mi cuenta
                      // — útil para probar skins y monedas sin grindear.
                      if (_profile?['email'] == 'bcarreres55@gmail.com') ...[
                        const SizedBox(height: 16),
                        _buildDebugCard(),
                      ],
                      const SizedBox(height: 24),
                      if (AppConfig.showAds)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: 200,
                              maxHeight: 250,
                            ),
                            child: _buildNativeAdOrBanner(),
                          ),
                        ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError(AppLocalizations l) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(l.profileLoadError, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadProfile, child: Text(l.retry)),
        ],
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    final email = _profile?['email'] as String? ?? '';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AlzitransColors.burgundy.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: AlzitransColors.burgundy, width: 2),
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: AlzitransColors.burgundy,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(email, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 4),
        Builder(builder: (context) {
          final l = AppLocalizations.of(context)!;
          return Text(
            '${l.memberSince} ${_formatDate(_profile?['createdAt'] as String?)}',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          );
        }),
      ],
    );
  }


  Widget _buildStatsCards(ThemeData theme, AppLocalizations l) {
    final stats = _profile?['stats'] as Map<String, dynamic>? ?? {};
    final totalTrips = stats['totalTrips'] as int? ?? 0;
    final mostUsedLine = stats['mostUsedLine'] as String? ?? '—';
    final thisMonthTrips = stats['thisMonthTrips'] as int? ?? 0;

    return Row(
      children: [
        _statCard(theme, Icons.directions_bus, l.totalTrips, '$totalTrips', AlzitransColors.burgundy),
        const SizedBox(width: 12),
        _statCard(theme, Icons.route, l.mostUsedLine, mostUsedLine, AlzitransColors.coral),
        const SizedBox(width: 12),
        _statCard(theme, Icons.calendar_month, l.thisMonth, '$thisMonthTrips', Colors.teal),
      ],
    );
  }

  Widget _statCard(ThemeData theme, IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNativeAdOrBanner() {
    if (kIsWeb) {
      return AdBannerWidget(
        adUnitId: AppConfig.settingsBannerAdId,
      );
    }
    
    final adService = ref.read(adServiceProvider);
    final preloadedAd = adService.profileNativeAd;

    if (preloadedAd != null) {
      return buildNativeAdStub(ad: preloadedAd);
    }

    // Si no hay precargado, mostrar banner estándar como respaldo
    return AdBannerWidget(
      adUnitId: AppConfig.settingsBannerAdId,
    );
  }

  Widget _buildInfoCard(ThemeData theme, AppLocalizations l) {
    final lastAccess = _formatDate(_profile?['lastAccess'] as String?);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.accountInfo,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _infoRow(Icons.email_outlined, l.email, _profile?['email'] as String? ?? '—'),
            const Divider(height: 24),
            _infoRow(Icons.access_time, l.lastAccess, lastAccess),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionsCard(ThemeData theme, AppLocalizations l) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.bar_chart, color: AlzitransColors.burgundy),
            title: Text(l.tripHistory),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => const TripHistoryRoute().push(context),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.emoji_events, color: AlzitransColors.burgundy),
            title: Text(l.rankingTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(l.rankingSubtitle, style: const TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => const RankingRoute().push(context),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.settings_outlined, color: AlzitransColors.burgundy),
            title: Text(l.tabSettings),
            trailing: const Icon(Icons.chevron_right),
            onTap: widget.onSettingsTap,
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.support_agent, color: AlzitransColors.burgundy),
            title: const Text('Ayuda y Soporte', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Reportar bugs, quejas o sugerencias', style: TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FeedbackScreen()),
              );
            },
          ),
          if (AppConfig.showAds && !kIsWeb) ...[
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(Icons.tv_off, color: AlzitransColors.burgundy),
              title: Text(l.removeAdsTitle, style: const TextStyle(color: AlzitransColors.burgundy, fontWeight: FontWeight.bold)),
              subtitle: Text(l.removeAdsSubtitle, style: const TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.stars, color: AlzitransColors.burgundy),
              onTap: () {
                final adService = ref.read(adServiceProvider);
                if (adService.isRewardedAdReady) {
                  showDialog(
                    context: context,
                    builder: (ctx) => const Center(child: CircularProgressIndicator()),
                  );
                  adService.showRewardedAd(
                    onRewarded: () {
                      if (mounted) {
                        Navigator.pop(context); // quitar dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l.adsHiddenSuccess),
                            backgroundColor: Colors.green,
                          ),
                        );
                        setState(() {}); // Forzar redibujado de la UI para ocultar banners
                      }
                    },
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l.adNotAvailable),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  adService.loadRewardedAd();
                }
              },
            ),
          ],
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: AlzitransColors.burgundy),
            title: Text(l.editEmail),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showChangeEmailDialog(l),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.lock_outline, color: AlzitransColors.burgundy),
            title: Text(l.changePassword),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showChangePasswordDialog(l),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.orange),
            title: Text(l.logout, style: const TextStyle(color: Colors.orange)),
            onTap: () => _confirmLogout(l),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: Text(l.deleteAccountTitle, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            subtitle: Text(l.deleteAccountSubtitle, style: const TextStyle(fontSize: 11)),
            onTap: () => _confirmDeleteAccount(l),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(AppLocalizations l) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l.deleteAccountDialogTitle, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.deleteAccountIrreversible),
            const SizedBox(height: 12),
            Text(l.deleteAccountBullet1),
            Text(l.deleteAccountBullet2),
            const SizedBox(height: 12),
            Text(
              l.deleteAccountConfirm(_profile?['email']?.toString() ?? ''),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              _performDeletion(l);
            },
            child: Text(l.deleteAccountConfirmButton),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeletion(AppLocalizations l) async {
    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (_token != null) {
        await ref.read(authProvider.notifier).deleteAccount(_token!);
        if (mounted) {
          Navigator.pop(context); // Quitar el loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.accountDeletedSuccess),
              backgroundColor: Colors.black,
            ),
          );
          // Redirigir al login (authProvider ya notificó el cambio de estado)
          const LoginRoute().go(context);
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Quitar el loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.genericError(e.toString())), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showChangeEmailDialog(AppLocalizations l) {
    final ctrl = TextEditingController(text: _profile?['email'] as String?);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l.editEmail),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: l.email,
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          ElevatedButton(
            onPressed: () async {
              final newEmail = ctrl.text.trim();
              if (newEmail.isEmpty) return;
              Navigator.pop(ctx);
              try {
                if (_token != null) {
                  await _auth.updateEmail(_token!, newEmail);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.emailUpdatedSuccess), backgroundColor: Colors.green),
                    );
                    _loadProfile();
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.genericError(e.toString())), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text(l.save),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(AppLocalizations l) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(l.changePassword),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentCtrl,
                obscureText: obscureCurrent,
                decoration: InputDecoration(
                  labelText: l.currentPassword,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscureCurrent ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setStateDialog(() => obscureCurrent = !obscureCurrent),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newCtrl,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: l.newPassword,
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(obscureNew ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setStateDialog(() => obscureNew = !obscureNew),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
            ElevatedButton(
              onPressed: () async {
                if (currentCtrl.text.isEmpty || newCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  if (_token != null) {
                    await _auth.updatePassword(_token!, currentCtrl.text, newCtrl.text);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l.passwordUpdatedSuccess),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.genericError(e.toString())), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(AppLocalizations l) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l.logout),
        content: Text(l.logoutConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (mounted) {
                const LoginRoute().go(context);
              }
            },
            child: Text(l.logout, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // SECCIÓN DEBUG · solo para el autor del TFC
  // ───────────────────────────────────────────────────────────────────
  /// Card morada con accesos rápidos para testear el sistema de skins
  /// sin tener que grindear horas. Solo se renderiza si el email del
  /// usuario es 'bcarreres55@gmail.com' (chequeado donde se llama).
  Widget _buildDebugCard() {
    return Card(
      elevation: 4,
      color: Colors.deepPurple.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.deepPurple.shade300, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science, color: Colors.deepPurple, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Debug · autor TFC',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Colors.deepPurple.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Solo visible en tu cuenta. Para probar skins sin grindear.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.deepPurple.shade400,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _debugButton('+1.000 🪙', Colors.amber.shade700, () => _grantCoins(1000)),
                _debugButton('+10.000 🪙', Colors.orange.shade700, () => _grantCoins(10000)),
                _debugButton('Desbloquear todas skins', Colors.deepPurple, _unlockAllSkins),
                _debugButton('Reset monedero (0)', Colors.red.shade400, _resetCoins),
                _debugButton('Reset cap diario', Colors.blue.shade600, _resetDailyCap),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _debugButton(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }

  Future<void> _grantCoins(int amount) async {
    // Usamos CoinSource.unlimited para saltarse el cap diario de juegos.
    final added = await ref.read(gameCurrencyProvider.notifier).add(
      amount,
      source: CoinSource.unlimited,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('+$added 🪙 al monedero'),
        backgroundColor: Colors.deepPurple,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _unlockAllSkins() async {
    final notifier = ref.read(ownedSkinsProvider.notifier);
    for (final skin in AlbusSkin.all) {
      await notifier.unlock(skin.id);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${AlbusSkin.all.length} skins desbloqueados'),
        backgroundColor: Colors.deepPurple,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _resetCoins() async {
    // Poner a 0: spend de TODO el saldo actual.
    final current = ref.read(gameCurrencyProvider);
    if (current > 0) {
      await ref.read(gameCurrencyProvider.notifier).spend(current);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Monedero a 0'), duration: Duration(seconds: 2)),
    );
  }

  Future<void> _resetDailyCap() async {
    // Borrar las keys del progreso del día. Las funciones del provider
    // las leen con fecha actual, si no hay valor → 0 → cap desbloqueado.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('coins_earned_today_v1');
      await prefs.remove('coins_earned_date_v1');
      await prefs.remove('coin_ads_today_v1');
      await prefs.remove('coin_ads_date_v1');
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cap diario reseteado — puedes ganar las 30+60 de nuevo'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
