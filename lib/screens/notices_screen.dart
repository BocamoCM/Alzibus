import 'package:flutter/material.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notices_service.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'dart:async';

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
  final _scrollController = ScrollController();
  List<NoticeMessage> _messages = [];
  bool _isLoading = true;
  bool _sending = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    // Refrescar cada 15 segundos si el widget sigue montado
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadMessages(silent: true));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);
    final msgs = await widget.service.getConversation(widget.notice.id);
    if (mounted) {
      final isNewMessage = msgs.length > _messages.length;
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
      if (isNewMessage) _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _send() async {
    final msg = _controller.text.trim();
    if (msg.isEmpty) return;
    setState(() => _sending = true);
    final ok = await widget.service.replyToNotice(widget.notice.id, msg);
    if (mounted) {
      setState(() => _sending = false);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar. Inténtalo de nuevo.'), backgroundColor: Colors.red),
        );
      } else {
        _controller.clear();
        _loadMessages();
      }
    }
  }

  String _formatDate(DateTime dt) {
    return DateFormat('dd/MM HH:mm').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.forum, size: 16, color: AlzitransColors.burgundy),
            const SizedBox(width: 8),
            Text('Conversación',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AlzitransColors.burgundy,
                )),
          ],
        ),
        const SizedBox(height: 12),
        // Área de mensajes
        Container(
          height: 250,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: _isLoading && _messages.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? const Center(child: Text('Sin mensajes aún.\nEscribe para empezar.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (ctx, i) {
                        final msg = _messages[i];
                        final isMe = !msg.isFromAdmin;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isMe ? const Color(0xFF6B1B3D) : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                                      bottomRight: Radius.circular(isMe ? 4 : 16),
                                    ),
                                    border: isMe ? null : Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      if (!isMe)
                                        Text('Administrador', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                                      Text(
                                        msg.message,
                                        style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDate(msg.createdAt),
                                        style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
        const SizedBox(height: 12),
        // Solo permitir escribir si el aviso sigue activo
        if (widget.notice.active)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: 'Escribe un mensaje...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(
                  color: AlzitransColors.burgundy,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: _sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _sending ? null : _send,
                ),
              ),
            ],
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
            child: const Text('Conversación cerrada (Aviso inactivo)', style: TextStyle(color: Colors.grey)),
          ),
      ],
    );
  }
}
