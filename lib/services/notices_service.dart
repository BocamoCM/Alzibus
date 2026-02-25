import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_config.dart';

class NoticeRecord {
  final int id;
  final String title;
  final String body;
  final String? line;
  final bool active;
  final DateTime? expiresAt;
  final DateTime createdAt;

  const NoticeRecord({
    required this.id,
    required this.title,
    required this.body,
    this.line,
    required this.active,
    this.expiresAt,
    required this.createdAt,
  });

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
      );
}

class NoticesService {
  List<NoticeRecord> _notices = [];

  List<NoticeRecord> get notices => List.unmodifiable(_notices);
  bool get hasActiveNotices => _notices.isNotEmpty;

  /// Carga los avisos activos desde la API.
  Future<List<NoticeRecord>> loadNotices() async {
    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.baseUrl}/notices'),
            headers: AppConfig.headers,
          )
          .timeout(AppConfig.httpTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _notices = data.map((e) => NoticeRecord.fromJson(e as Map<String, dynamic>)).toList();
        debugPrint('[NoticesService] ${_notices.length} avisos cargados');
      }
    } catch (e) {
      debugPrint('[NoticesService] Error cargando avisos: $e');
    }
    return _notices;
  }
}
