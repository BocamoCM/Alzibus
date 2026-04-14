import 'package:flutter/material.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notices_service.dart';
import '../theme/app_theme.dart';

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
    if (diff.inSeconds < 0) return _formatFutureDate(dt, now);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatFutureDate(DateTime dt, DateTime now) {
    final diff = dt.difference(now);
    if (diff.inMinutes < 60) return 'En ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'En ${diff.inHours}h';
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
    final isPersonal = notice.isPersonal;

    // Avisos personales tienen borde y estilo diferenciado
    final borderColor = isPersonal
        ? AlzitransColors.burgundy.withOpacity(0.5)
        : (hasLine ? lineColor.withOpacity(0.3) : Colors.orange.withOpacity(0.3));
    final headerColor = isPersonal
        ? AlzitransColors.burgundy.withOpacity(0.08)
        : (hasLine ? lineColor.withOpacity(0.1) : Colors.orange.withOpacity(0.1));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isPersonal ? 1.5 : 1.0),
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
              color: headerColor,
              child: Row(
                children: [
                  Icon(
                    isPersonal ? Icons.mark_email_unread_rounded : Icons.warning_amber_rounded,
                    color: isPersonal ? AlzitransColors.burgundy : (hasLine ? lineColor : Colors.orange),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  if (isPersonal) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: AlzitransColors.burgundy,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Mensaje para ti',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (hasLine && !isPersonal) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: lineColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(notice.line!,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(notice.body,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
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
                  // ── Sección de respuesta (solo avisos personales) ──
                  if (isPersonal) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    _ReplyWidget(
                      notice: notice,
                      service: _service,
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

/// Widget de respuesta embebido en la tarjeta del aviso personal.
class _ReplyWidget extends StatefulWidget {
  final NoticeRecord notice;
  final NoticesService service;

  const _ReplyWidget({required this.notice, required this.service});

  @override
  State<_ReplyWidget> createState() => _ReplyWidgetState();
}

class _ReplyWidgetState extends State<_ReplyWidget> {
  final _controller = TextEditingController();
  bool _sent = false;
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final msg = _controller.text.trim();
    if (msg.isEmpty) return;
    setState(() => _sending = true);
    final ok = await widget.service.replyToNotice(widget.notice.id, msg);
    if (mounted) {
      setState(() {
        _sending = false;
        _sent = ok;
      });
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar la respuesta. Inténtalo de nuevo.'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Text('Respuesta enviada', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Responder al administrador',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AlzitransColors.burgundy,
            )),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Escribe tu respuesta...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send, size: 18),
            label: Text(_sending ? 'Enviando...' : 'Enviar respuesta'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AlzitransColors.burgundy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
