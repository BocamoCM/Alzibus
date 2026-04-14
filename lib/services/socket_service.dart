import 'dart:async';
import 'package:flutter/material.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../main.dart'; // Para navigatorKey
import '../services/notices_service.dart';

/// SocketService — Avisos en tiempo real mediante polling HTTP.
///
/// La librería socket_io_client para Dart tiene un bug conocido donde
/// el puerto de la URL siempre se interpreta como :0, haciendo imposible
/// la conexión WebSocket. Como alternativa robusta, esta clase implementa
/// polling HTTP cada 30 segundos usando la infraestructura HTTP existente
/// que ya funciona correctamente.
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  final _attendeesController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onAttendeesUpdate => _attendeesController.stream;

  Timer? _pollingTimer;
  int? _lastSeenNoticeId;
  bool _isPolling = false;

  /// Inicia el polling de avisos. Llama a este método cuando el usuario
  /// ha iniciado sesión y la app está activa.
  void initialize() {
    if (_isPolling) return;
    _isPolling = true;

    debugPrint('[SocketService] ✅ Iniciando polling de avisos cada 30s...');

    // Lanzar la primera consulta inmediatamente
    _checkForNewNotices();

    // Repetir cada 30 segundos
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkForNewNotices();
    });
  }

  /// Consulta el endpoint de avisos y muestra un popup si hay uno nuevo.
  Future<void> _checkForNewNotices() async {
    try {
      final response = await ApiClient().get('/notices');
      if (response == null) return;

      // ApiClient devuelve el objeto Response de Dio — extraer los datos con .data
      final rawData = response.data;
      
      List<dynamic> notices;
      if (rawData is List) {
        notices = rawData;
      } else if (rawData is Map && rawData['notices'] != null) {
        notices = rawData['notices'] as List;
      } else {
        return;
      }

      if (notices.isEmpty) return;

      // Obtener el aviso más reciente (asumimos que vienen ordenados DESC)
      final latestNotice = notices.first as Map<String, dynamic>;
      final latestId = latestNotice['id'] as int?;

      if (latestId == null) return;

      // Si es la primera consulta, guardar el ID actual sin mostrar popup
      // (no queremos mostrar avisos viejos al iniciar)
      if (_lastSeenNoticeId == null) {
        _lastSeenNoticeId = latestId;
        debugPrint('[SocketService] 🔄 ID inicial de avisos guardado: $latestId');
        return;
      }

      // Si hay un aviso más nuevo, mostrarlo
      if (latestId > _lastSeenNoticeId!) {
        _lastSeenNoticeId = latestId;
        debugPrint('[SocketService] 🔔 Nuevo aviso detectado (ID: $latestId): ${latestNotice['title']}');
        _showNoticeDialog(latestNotice);
      }
    } catch (e) {
      debugPrint('[SocketService] ⚠️ Error en polling de avisos: $e');
    }
  }

  /// Método mantenido por compatibilidad interna.
  Future<void> _sendDebugLog(String message, {dynamic data}) async {
    // Debug logging desactivado — el sistema ya funciona correctamente.
    debugPrint('[SocketService] $message');
  }

  void _showNoticeDialog(dynamic data) {
    // 1. Verificar contexto disponible con reintento si es null
    if (navigatorKey.currentContext == null) {
      debugPrint('[SocketService] ⚠️ Contexto null, reintentando mostrar diálogo en 1s...');
      Future.delayed(const Duration(seconds: 1), () => _showNoticeDialog(data));
      return;
    }

    // 2. Ejecutar tras el frame actual para evitar conflictos de construcción
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context == null) return;

      try {
        final l = AppLocalizations.of(context);
        if (l == null) {
          debugPrint('[SocketService] ⚠️ No se encontró AppLocalizations en este frame. Reintentando...');
          Future.delayed(const Duration(seconds: 1), () => _showNoticeDialog(data));
          return;
        }

        // Extraer datos del aviso de forma segura
        final title = data['title']?.toString() ?? l.newNoticePopupTitle;
        final body = data['body']?.toString() ?? '';
        final line = data['line'];
        final targetEmail = data['target_email'] as String?;
        final noticeId = data['id'] as int?;
        final isPersonal = targetEmail != null && noticeId != null;

        debugPrint('[SocketService] 🚀 Mostrando diálogo de aviso (${isPersonal ? "personal" : "general"}): $title');

        showDialog(
          context: context,
          barrierDismissible: true,
          useRootNavigator: true,
          builder: (ctx) => isPersonal
              ? _PersonalNoticeDialog(
                  title: title,
                  body: body,
                  noticeId: noticeId!,
                )
              : AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      const Icon(Icons.campaign, color: AlzitransColors.burgundy, size: 28),
                      const SizedBox(width: 8),
                      Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (line != null && line.toString().trim().isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AlzitransColors.coral,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${l.line} $line',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(body, style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(l.understood, style: const TextStyle(color: AlzitransColors.burgundy, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
        );
      } catch (e) {
        debugPrint('[SocketService] ❌ Error fatal mostrando diálogo: $e');
      }
    });
  }

  // Mantener compatibilidad con el código existente que usa emitAttendBus
  void emitAttendBus(String line, String stopId) {
    // El polling no requiere emitir eventos, se mantiene por compatibilidad
    debugPrint('[SocketService] emitAttendBus llamado (modo polling): line=$line, stop=$stopId');
  }

  void dispose() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    if (!_attendeesController.isClosed) {
      _attendeesController.close();
    }
  }
}

/// Diálogo emergente para avisos personales.
/// Incluye campo de texto para responder desde el momento en que llega el aviso.
/// Si el usuario prefiere responder luego, puede cerrar y hacerlo desde la pantalla de Avisos.
class _PersonalNoticeDialog extends StatefulWidget {
  final String title;
  final String body;
  final int noticeId;

  const _PersonalNoticeDialog({
    required this.title,
    required this.body,
    required this.noticeId,
  });

  @override
  State<_PersonalNoticeDialog> createState() => _PersonalNoticeDialogState();
}

class _PersonalNoticeDialogState extends State<_PersonalNoticeDialog> {
  final _controller = TextEditingController();
  final _service = NoticesService();
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final msg = _controller.text.trim();
    if (msg.isEmpty) return;
    setState(() => _sending = true);
    final ok = await _service.replyToNotice(widget.noticeId, msg);
    if (mounted) setState(() { _sending = false; _sent = ok; });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.mark_email_unread_rounded, color: AlzitransColors.burgundy, size: 26),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.body, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            if (_sent) ...
              [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text('¡Respuesta enviada!',
                        style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
                  ],
                ),
              ]
            else ...
              [
                Text('Responder al administrador',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold, color: AlzitransColors.burgundy)),
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
              ],
          ],
        ),
      ),
      actions: [
        // "Más tarde" — cierra el popup, el aviso sigue en la pantalla de Avisos
        if (!_sent)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Responder más tarde',
                style: TextStyle(color: Colors.grey)),
          ),
        if (_sent)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.understood,
                style: const TextStyle(color: AlzitransColors.burgundy, fontWeight: FontWeight.bold)),
          )
        else
          ElevatedButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send, size: 18),
            label: Text(_sending ? 'Enviando...' : 'Enviar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AlzitransColors.burgundy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
      ],
    );
  }
}
