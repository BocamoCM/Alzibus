import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';

class NoticeRecord {
  final int id;
  final String title;
  final String body;
  final String? line;
  final bool active;
  final DateTime? expiresAt;
  final DateTime createdAt;
  /// Si no es null, este aviso es personal y solo visible para ese email.
  final String? targetEmail;

  const NoticeRecord({
    required this.id,
    required this.title,
    required this.body,
    this.line,
    required this.active,
    this.expiresAt,
    required this.createdAt,
    this.targetEmail,
  });

  /// True si el aviso es personal (tiene destinatario concreto).
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
      );
}

class NoticesService {
  List<NoticeRecord> _notices = [];

  List<NoticeRecord> get notices => List.unmodifiable(_notices);
  bool get hasActiveNotices => _notices.isNotEmpty;

  /// Carga los avisos activos desde la API.
  /// El servidor filtra automáticamente por usuario autenticado (via JWT).
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

  /// Envía una respuesta al aviso personal con el [noticeId] dado.
  /// Devuelve true si se guardó correctamente.
  Future<bool> replyToNotice(int noticeId, String message) async {
    try {
      final response = await ApiClient().post(
        '/notices/$noticeId/reply',
        data: {'message': message},
      );
      return response.statusCode == 201;
    } catch (e) {
      debugPrint('[NoticesService] Error enviando respuesta: $e');
      return false;
    }
  }
}
