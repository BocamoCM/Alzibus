import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class NoticesAdminScreen extends StatefulWidget {
  const NoticesAdminScreen({super.key});

  @override
  State<NoticesAdminScreen> createState() => _NoticesAdminScreenState();
}

class _NoticesAdminScreenState extends State<NoticesAdminScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _notices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _notices = await _api.getAdminNotices();
    if (mounted) setState(() => _isLoading = false);
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '—';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal());
  }

  Color _lineColor(String? lineId) {
    switch (lineId) {
      case 'L1': return const Color(0xFF1565C0);
      case 'L2': return const Color(0xFF2E7D32);
      case 'L3': return const Color(0xFFE65100);
      default:   return Colors.grey;
    }
  }

  void _showCreateDialog() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final targetEmailCtrl = TextEditingController();
    String? selectedLine;
    DateTime? expiresAt;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.campaign, color: Color(0xFF6B1B3D)),
              SizedBox(width: 10),
              Text('Crear aviso'),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Título *',
                      prefixIcon: const Icon(Icons.title),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Descripción *',
                      prefixIcon: const Icon(Icons.description),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Email del destinatario (aviso personal)
                  TextField(
                    controller: targetEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email del destinatario (opcional)',
                      hintText: 'Dejar vacío para aviso general',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      helperText: 'Si lo rellenas, solo ese usuario verá el aviso y podrá responderte.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Selector de línea
                  DropdownButtonFormField<String?>(
                    value: selectedLine,
                    decoration: InputDecoration(
                      labelText: 'Línea afectada (opcional)',
                      prefixIcon: const Icon(Icons.route),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas las líneas')),
                      ...['L1', 'L2', 'L3'].map((l) => DropdownMenuItem(
                            value: l,
                            child: Row(
                              children: [
                                Container(
                                  width: 12, height: 12,
                                  decoration: BoxDecoration(color: _lineColor(l), shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                Text(l),
                              ],
                            ),
                          )),
                    ],
                    onChanged: (v) => setStateDialog(() => selectedLine = v),
                  ),
                  const SizedBox(height: 12),
                  // Selector fecha vencimiento
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setStateDialog(() => expiresAt = picked);
                      }
                    },
                    icon: const Icon(Icons.schedule),
                    label: Text(expiresAt != null
                        ? 'Vence: ${_formatDate(expiresAt!.toIso8601String())}'
                        : 'Sin fecha de vencimiento'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Publicar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B1B3D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (titleCtrl.text.isEmpty || bodyCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('El título y la descripción son obligatorios')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final targetEmail = targetEmailCtrl.text.trim().isEmpty ? null : targetEmailCtrl.text.trim();
                final result = await _api.createNotice(
                  title: titleCtrl.text.trim(),
                  body: bodyCtrl.text.trim(),
                  line: selectedLine,
                  expiresAt: expiresAt,
                  targetEmail: targetEmail,
                );
                if (result != null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(targetEmail != null
                            ? '✅ Aviso personal enviado a $targetEmail'
                            : '✅ Aviso general publicado'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                  _load();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Muestra el hilo de respuestas de un aviso personal.
  void _showReplies(Map<String, dynamic> notice) async {
    final noticeId = notice['id'] as int;
    final replies = await _api.getNoticeReplies(noticeId);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.forum_outlined, color: Color(0xFF6B1B3D)),
            const SizedBox(width: 10),
            Expanded(child: Text('Respuestas: ${notice['title']}', overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: replies.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Sin respuestas todavía.')),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: replies.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final reply = replies[i];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF6B1B3D),
                        child: Icon(Icons.person, color: Colors.white, size: 18),
                      ),
                      title: Text(reply['user_email'] as String),
                      subtitle: Text(reply['message'] as String),
                      trailing: Text(
                        _formatDate(reply['created_at'] as String?),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleNotice(Map<String, dynamic> notice) async {
    final id = notice['id'] as int;
    await _api.toggleNotice(id);
    _load();
  }

  Future<void> _deleteNotice(Map<String, dynamic> notice) async {
    final id = notice['id'] as int;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar aviso'),
        content: Text('¿Eliminar "${notice['title']}"? Esta acción es irreversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _api.deleteNotice(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aviso eliminado'), backgroundColor: Colors.red),
        );
      }
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = _notices.where((n) => n['active'] == true).length;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Avisos e Incidencias',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text(
                    '$active activos · ${_notices.length} total',
                    style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add),
                label: const Text('Nuevo aviso'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B1B3D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        // Lista
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _notices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.campaign_outlined, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('Sin avisos publicados',
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(color: Colors.grey[500])),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _showCreateDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Crear primer aviso'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6B1B3D),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _notices.length,
                        itemBuilder: (context, index) =>
                            _buildNoticeCard(_notices[index], theme),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildNoticeCard(Map<String, dynamic> notice, ThemeData theme) {
    final isActive = notice['active'] as bool? ?? true;
    final line = notice['line'] as String?;
    final lineColor = _lineColor(line);
    final expiresAt = notice['expires_at'] as String?;
    final targetEmail = notice['target_email'] as String?;
    final isPersonal = targetEmail != null;

    final borderColor = isPersonal
        ? const Color(0xFF6B1B3D).withOpacity(0.4)
        : (isActive ? lineColor.withOpacity(0.3) : Colors.grey.withOpacity(0.2));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: isPersonal ? 1.5 : 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Chip de línea
                if (line != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: lineColor, borderRadius: BorderRadius.circular(20)),
                    child: Text(line,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                ],
                // Chip personal
                if (isPersonal) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B1B3D).withOpacity(0.1),
                      border: Border.all(color: const Color(0xFF6B1B3D).withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person, size: 12, color: Color(0xFF6B1B3D)),
                        const SizedBox(width: 4),
                        Text(targetEmail,
                            style: const TextStyle(color: Color(0xFF6B1B3D), fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Chip de estado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? 'Activo' : 'Inactivo',
                    style: TextStyle(
                      color: isActive ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(notice['created_at'] as String?),
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(notice['title'] as String,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(notice['body'] as String,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
            if (expiresAt != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('Vence: ${_formatDate(expiresAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Botón de respuestas (solo avisos personales)
                if (isPersonal) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.forum_outlined, size: 18),
                    label: const Text('Ver respuestas'),
                    onPressed: () => _showReplies(notice),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B1B3D),
                      side: const BorderSide(color: Color(0xFF6B1B3D)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Toggle activo
                OutlinedButton.icon(
                  icon: Icon(isActive ? Icons.pause_circle_outline : Icons.play_circle_outline, size: 18),
                  label: Text(isActive ? 'Desactivar' : 'Activar'),
                  onPressed: () => _toggleNotice(notice),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isActive ? Colors.orange : Colors.green,
                    side: BorderSide(color: isActive ? Colors.orange : Colors.green),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Eliminar',
                  onPressed: () => _deleteNotice(notice),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
