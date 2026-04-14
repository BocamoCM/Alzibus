import 'dart:async';
import 'package:flutter/material.dart';
import 'package:alzitrans/l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../main.dart'; // Para navigatorKey
import '../services/notices_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/notification_service.dart';

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

  final _noticesService = NoticesService();
  Timer? _pollingTimer;
  int? _lastSeenNoticeId;
  int? _lastSeenAdminReplyId;
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
  /// Delega en NoticesService para no duplicar la lógica HTTP.
  Future<void> _checkForNewNotices() async {
    try {
      final notices = await _noticesService.loadNotices();
      if (notices.isEmpty) return;

      // Obtener el aviso más reciente (vienen ordenados DESC del servidor)
      final latestNotice = notices.first;
      final latestId = latestNotice.id;

      // Buscar el ID máximo de respuesta del admin
      int currentMaxReplyId = 0;
      for (final n in notices) {
        if (n.lastAdminReplyId != null && n.lastAdminReplyId! > currentMaxReplyId) {
          currentMaxReplyId = n.lastAdminReplyId!;
        }
      }

      // Si es la primera consulta, guardar el ID actual sin mostrar popup
      // (no queremos mostrar avisos viejos al iniciar la app)
      if (_lastSeenNoticeId == null) {
        _lastSeenNoticeId = latestId;
        _lastSeenAdminReplyId = currentMaxReplyId;
        debugPrint('[SocketService] 🔄 ID inicial de avisos guardado: $latestId, respuestas: $currentMaxReplyId');
        return;
      }

      bool showPopup = false;
      dynamic noticeData;

      // Si hay un aviso más nuevo que el último visto, mostrarlo
      if (latestId > _lastSeenNoticeId!) {
        _lastSeenNoticeId = latestId;
        showPopup = true;
        noticeData = {
          'id': latestNotice.id,
          'title': latestNotice.title,
          'body': latestNotice.body,
          'line': latestNotice.line,
          'target_email': latestNotice.targetEmail,
        };
        debugPrint('[SocketService] 🔔 Nuevo aviso detectado (ID: $latestId): ${latestNotice.title}');
        
        final notifService = NotificationService(FlutterLocalNotificationsPlugin());
        notifService.showNoticeNotification('Nuevo aviso de Alzibus', latestNotice.title);
      } 
      // O si hay una respuesta nueva a un aviso existente
      else if (_lastSeenAdminReplyId != null && currentMaxReplyId > _lastSeenAdminReplyId!) {
        _lastSeenAdminReplyId = currentMaxReplyId;
        final repliedNotice = notices.firstWhere((n) => n.lastAdminReplyId == currentMaxReplyId);
        showPopup = true;
        noticeData = {
          'id': repliedNotice.id,
          'title': 'Nueva respuesta',
          'body': 'El administrador ha respondido en el aviso "${repliedNotice.title}".',
          'line': repliedNotice.line,
          'target_email': repliedNotice.targetEmail,
        };
        debugPrint('[SocketService] 🔔 Nueva respuesta detectada (ReplyID: $currentMaxReplyId)');
        
        final notifService = NotificationService(FlutterLocalNotificationsPlugin());
        notifService.showNoticeNotification('Respuesta del Administrador', repliedNotice.title);
      }

      if (showPopup && noticeData != null) {
        _showNoticeDialog(noticeData);
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
class _PersonalNoticeDialog extends StatelessWidget {
  final String title;
  final String body;
  final int noticeId;

  const _PersonalNoticeDialog({
    required this.title,
    required this.body,
    required this.noticeId,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.mark_email_unread_rounded, color: AlzitransColors.burgundy, size: 26),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.forum, color: AlzitransColors.burgundy, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Tienes un chat abierto con el administrador para este aviso.',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            // TODO: Podríamos navegar directamente a la pantalla de avisos aquí si tuviéramos un router
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ve a la pestaña "Avisos" para responder.')),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AlzitransColors.burgundy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Ir a mensajes'),
        ),
      ],
    );
  }
}
