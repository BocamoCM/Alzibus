import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    _users = await _api.getUsers();
    _filtered = List.from(_users);
    if (mounted) setState(() => _isLoading = false);
  }

  void _filter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _users.where((u) => (u['email'] as String).toLowerCase().contains(q)).toList();
    });
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '—';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal());
  }

  Future<void> _toggleUser(Map<String, dynamic> user) async {
    final isActive = user['active'] as bool? ?? true;
    final email = user['email'] as String;
    final id = user['id'] as int;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isActive ? 'Desactivar usuario' : 'Activar usuario'),
        content: Text(
          isActive
              ? '¿Desactivar la cuenta de $email? No podrá iniciar sesión.'
              : '¿Activar la cuenta de $email?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? Colors.red : Colors.green,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isActive ? 'Desactivar' : 'Activar',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    final updated = await _api.toggleUserStatus(id);
    if (updated != null) {
      final idx = _users.indexWhere((u) => u['id'] == id);
      if (idx != -1) {
        setState(() {
          _users[idx] = {..._users[idx], 'active': updated['active']};
          _filter();
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updated['active'] == true
                ? '✅ Cuenta de $email activada'
                : '🔒 Cuenta de $email desactivada'),
            backgroundColor: updated['active'] == true ? Colors.green : Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Usuarios',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text(
                    '${_users.length} usuarios registrados',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: _loadUsers,
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualizar',
              ),
            ],
          ),
        ),
        // Buscador
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por email...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _filter();
                      },
                    )
                  : null,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        // Stats rápidas
        if (!_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _quickStat(theme, 'Total', '${_users.length}', Icons.people, Colors.blue),
                const SizedBox(width: 12),
                _quickStat(
                  theme,
                  'Activos',
                  '${_users.where((u) => u['active'] == true).length}',
                  Icons.check_circle_outline,
                  Colors.green,
                ),
                const SizedBox(width: 12),
                _quickStat(
                  theme,
                  'Inactivos',
                  '${_users.where((u) => u['active'] == false).length}',
                  Icons.block,
                  Colors.red,
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        // Lista
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_search, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('Sin resultados', style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadUsers,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) =>
                            _buildUserTile(_filtered[index], theme),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _quickStat(ThemeData theme, String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold, color: color)),
                Text(label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, ThemeData theme) {
    final email = user['email'] as String;
    final isActive = user['active'] as bool? ?? true;
    final tripCount = user['trip_count'] as int? ?? 0;
    final lastAccess = _formatDate(user['last_access'] as String?);
    final createdAt = _formatDate(user['created_at'] as String?);
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isActive
                ? const Color(0xFF6B1B3D).withOpacity(0.15)
                : Colors.grey[200],
            child: Text(
              initial,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isActive ? const Color(0xFF6B1B3D) : Colors.grey,
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(email,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive ? 'Activo' : 'Inactivo',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.directions_bus, size: 13, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text('$tripCount viajes', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(width: 16),
                  Icon(Icons.login, size: 13, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text('Último acceso: $lastAccess',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(width: 16),
                  _buildOnlineBadge(user['is_online'] == true),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 13, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text('Registrado: $createdAt',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ],
          ),
          trailing: IconButton(
            icon: Icon(
              isActive ? Icons.block : Icons.check_circle_outline,
              color: isActive ? Colors.red : Colors.green,
            ),
            tooltip: isActive ? 'Desactivar' : 'Activar',
            onPressed: () => _toggleUser(user),
          ),
          isThreeLine: true,
        ),
      ),
    );
  }

  Widget _buildOnlineBadge(bool isOnline) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isOnline ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnline ? Colors.green.withOpacity(0.5) : Colors.grey.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isOnline ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isOnline ? 'En línea' : 'No en línea',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isOnline ? Colors.green : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
