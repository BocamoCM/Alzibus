import 'package:flutter/material.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../screens/trip_history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/premium_page.dart';

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
                      const SizedBox(height: 16),
                      _buildInfoCard(theme, l),
                      const SizedBox(height: 16),
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
              colors: [AlzitransColors.burgundy, AlzitransColors.wine],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AlzitransColors.burgundy.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              /*
              if (_profile?['isPremium'] == true)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.diamond, color: AlzitransColors.burgundy, size: 20),
                  ),
                ),
              */
            ],
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

  Widget _buildPremiumCard(ThemeData theme, AppLocalizations l) {
    final isPremium = _profile?['isPremium'] == true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isPremium
            ? const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [AlzitransColors.burgundy.withOpacity(0.9), AlzitransColors.wine],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isPremium ? Colors.orange : AlzitransColors.burgundy).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isPremium ? Icons.diamond : Icons.workspace_premium,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPremium ? 'USUARIO PREMIUM' : 'PÁSATE A PREMIUM',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      isPremium
                          ? 'Gracias por apoyar Alzitrans'
                          : 'Quita los anuncios para siempre',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isPremium) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PremiumPage()),
                  ).then((_) => _loadProfile()); // Recargar al volver
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AlzitransColors.burgundy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('MÁS INFORMACIÓN', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
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
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TripHistoryScreen()),
            ),
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
            title: const Text('Eliminar cuenta', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            subtitle: const Text('Borrado permanente de todos tus datos', style: TextStyle(fontSize: 11)),
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
        title: const Text('¿Eliminar tu cuenta?', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Esta acción es irreversible. Se borrarán permanentemente:'),
            const SizedBox(height: 12),
            const Text('• Tu historial de viajes y estadísticas.'),
            const Text('• Tus paradas favoritas.'),
            const Text('• Tu suscripción Premium.'),
            const SizedBox(height: 12),
            Text('¿Estás totalmente seguro de que quieres eliminar la cuenta de ${_profile?['email']}?', style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              _performDeletion();
            },
            child: const Text('SÍ, ELIMINAR TODO'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeletion() async {
    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (_token != null) {
        final success = await _auth.deleteAccount(_token!);
        if (success && mounted) {
          Navigator.pop(context); // Quitar el loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cuenta eliminada con éxito. Sentimos que te vayas.'),
              backgroundColor: Colors.black,
            ),
          );
          // Redirigir al login (AuthService ya limpió el token localmente)
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Quitar el loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
