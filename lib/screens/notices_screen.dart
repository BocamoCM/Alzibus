import 'package:flutter/material.dart';
import 'package:alzibus/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notices_service.dart';

/// Pantalla de avisos e incidencias activas del servicio de autobus.
class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  final NoticesService _service = NoticesService();
  List<NoticeRecord> _notices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _notices = await _service.loadNotices();
    // Marcar avisos como vistos
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_seen_notices_at', DateTime.now().toIso8601String());
    if (mounted) setState(() => _isLoading = false);
  }

  Color _lineColor(String? lineId) {
    switch (lineId) {
      case 'L1': return const Color(0xFF1565C0);
      case 'L2': return const Color(0xFF2E7D32);
      case 'L3': return const Color(0xFFE65100);
      default:   return Colors.grey;
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.notices),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: l.update,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _notices.isEmpty
                  ? _buildEmpty(theme, l)
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notices.length,
                      itemBuilder: (context, index) =>
                          _buildNoticeCard(_notices[index], theme),
                    ),
            ),
    );
  }

  Widget _buildEmpty(ThemeData theme, AppLocalizations l) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.green[300]),
            const SizedBox(height: 16),
            Text(
              l.noActiveNotices,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l.serviceNormal,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoticeCard(NoticeRecord notice, ThemeData theme) {
    final l = AppLocalizations.of(context)!;
    final hasLine = notice.line != null;
    final lineColor = _lineColor(notice.line);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasLine ? lineColor.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: hasLine ? lineColor.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: hasLine ? lineColor : Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  if (hasLine) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: lineColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(notice.line!,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Spacer(),
                  Text(
                    _formatDate(notice.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            // Contenido
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notice.title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(notice.body,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey[700])),
                  if (notice.expiresAt != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '${l.validUntil}: ${_formatDate(notice.expiresAt!)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
