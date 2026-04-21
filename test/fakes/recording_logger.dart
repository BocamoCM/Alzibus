import 'package:alzitrans/domain/exceptions/app_failure.dart';
import 'package:alzitrans/domain/ports/outbound/logger_port.dart';

/// Logger fake que graba todo lo que recibe para asertar en tests.
class RecordingLogger implements LoggerPort {
  final List<AppFailure> failures = [];
  final List<Object> exceptions = [];
  final List<({LogLevel level, String message})> logs = [];
  final List<String> breadcrumbs = [];
  ({String? id, String? email})? lastUser;

  @override
  Future<void> captureFailure(AppFailure failure) async {
    failures.add(failure);
  }

  @override
  Future<void> captureException(Object error, [StackTrace? stackTrace]) async {
    exceptions.add(error);
  }

  @override
  Future<void> log(LogLevel level, String message,
      {Map<String, Object?>? extra}) async {
    logs.add((level: level, message: message));
  }

  @override
  void breadcrumb(String message, {String? category, Map<String, Object?>? data}) {
    breadcrumbs.add(message);
  }

  @override
  Future<void> setUser({String? id, String? email}) async {
    lastUser = (id: id, email: email);
  }
}
