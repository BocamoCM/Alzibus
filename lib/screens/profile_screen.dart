import 'package:flutter/material.dart';
import 'package:alzibus/l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../screens/trip_history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pantalla de perfil del usuario: muestra datos personales y estadísticas de viajes.
class ProfileScreen extends StatefulWidget {
  final VoidCallback? onSettingsTap;
  const ProfileScreen({super.key, this.onSettingsTap});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _auth = AuthService();
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
                      const SizedBox(height: 24),
                      _buildActionsCard(theme, l),
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
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AlzibusColors.burgundy, AlzibusColors.wine],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AlzibusColors.burgundy.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(email, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
        _statCard(theme, Icons.directions_bus, l.totalTrips, '$totalTrips', AlzibusColors.burgundy),
        const SizedBox(width: 12),
        _statCard(theme, Icons.route, l.mostUsedLine, mostUsedLine, AlzibusColors.coral),
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
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
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
            leading: const Icon(Icons.bar_chart, color: AlzibusColors.burgundy),
            title: Text(l.tripHistory),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TripHistoryScreen()),
            ),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.settings_outlined, color: AlzibusColors.burgundy),
            title: Text(l.tabSettings),
            trailing: const Icon(Icons.chevron_right),
            onTap: widget.onSettingsTap,
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: AlzibusColors.burgundy),
            title: Text(l.editEmail),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showChangeEmailDialog(l),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.lock_outline, color: AlzibusColors.burgundy),
            title: Text(l.changePassword),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showChangePasswordDialog(l),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(l.logout, style: const TextStyle(color: Colors.red)),
            onTap: () => _confirmLogout(l),
          ),
        ],
      ),
    );
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
                      SnackBar(content: Text('✅ ${l.email} actualizado'), backgroundColor: Colors.green),
                    );
                    _loadProfile();
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
                          content: Text('✅ ${l.changePassword}'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
              await _auth.logout();
              if (mounted) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
                }
              }
            },
            child: Text(l.logout, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
