import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';

/// Modelo de un aviso (general o personal).
class NoticeRecord {
  final int id;
  final String title;
  final String body;
  final String? line;
  final bool active;
  final DateTime? expiresAt;
  final DateTime createdAt;
  /// Si no es null, este aviso es personal (solo visible para ese email).
  final String? targetEmail;
  final int? lastAdminReplyId;

  const NoticeRecord({
    required this.id,
    required this.title,
    required this.body,
    this.line,
    required this.active,
    this.expiresAt,
    required this.createdAt,
    this.targetEmail,
    this.lastAdminReplyId,
  });

  bool get isPersonal => targetEmail != null;

  factory NoticeRecord.fromJson(Map<String, dynamic> json) => NoticeRecord(
        id: json['id'] as int,
        title: json['title'] as String,
        body: json['body'] as String,
        line: json['line'] as String?,
        active: json['active'] as bool? ?? true,
        expiresAt: json['expires_at'] != null
            ? DateTime.tryParse(json['expires_at'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
        targetEmail: json['target_email'] as String?,
        lastAdminReplyId: json['last_admin_reply_id'] as int?,
      );
}

/// Modelo de un mensaje en la conversación de un aviso personal.
class NoticeMessage {
  final int id;
  final String message;
  /// 'user' = mensaje enviado por el usuario, 'admin' = respuesta del admin.
  final String senderType;
  final DateTime createdAt;

  const NoticeMessage({
    required this.id,
    required this.message,
    required this.senderType,
    required this.createdAt,
  });

  bool get isFromAdmin => senderType == 'admin';

  factory NoticeMessage.fromJson(Map<String, dynamic> json) => NoticeMessage(
        id: json['id'] as int,
        message: json['message'] as String,
        senderType: json['sender_type'] as String? ?? 'user',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class NoticesService {
  List<NoticeRecord> _notices = [];

  List<NoticeRecord> get notices => List.unmodifiable(_notices);
  bool get hasActiveNotices => _notices.isNotEmpty;

  /// Carga los avisos activos desde la API.
  Future<List<NoticeRecord>> loadNotices() async {
    try {
      final response = await ApiClient().get('/notices');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _notices = data.map((e) => NoticeRecord.fromJson(e as Map<String, dynamic>)).toList();
        debugPrint('[NoticesService] ${_notices.length} avisos cargados');
      }
    } catch (e) {
      debugPrint('[NoticesService] Error cargando avisos: $e');
    }
    return _notices;
  }

  /// Carga la conversación completa de un aviso personal.
  Future<List<NoticeMessage>> getConversation(int noticeId) async {
    try {
      final response = await ApiClient().get('/notices/$noticeId/messages');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((e) => NoticeMessage.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[NoticesService] Error cargando conversación: $e');
    }
    return [];
  }

  /// Envía un mensaje del usuario al aviso personal.
  Future<bool> replyToNotice(int noticeId, String message) async {
    try {
      final response = await ApiClient().post(
        '/notices/$noticeId/reply',
        data: {'message': message},
      );
      return response.statusCode == 201;
    } catch (e) {
      debugPrint('[NoticesService] Error enviando mensaje: $e');
      return false;
    }
  }
}
