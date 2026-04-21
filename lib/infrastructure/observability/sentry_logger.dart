import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/logger_port.dart';

/// Adaptador de [LoggerPort] sobre Sentry.
///
/// Cada `AppFailure` se reporta con su `code` como tag para poder filtrar en
/// el dashboard de Sentry, y con `cause`/`stackTrace` cuando existen.
class SentryLogger implements LoggerPort {
  const SentryLogger();

  @override
  Future<void> captureFailure(AppFailure failure) async {
    final cause = failure.cause;
    final stack = failure.stackTrace;
    if (cause != null) {
      await Sentry.captureException(
        cause,
        stackTrace: stack,
        withScope: (scope) {
          scope.setTag('failure_code', failure.code);
          if (failure.userMessage != null) {
            scope.setExtra('user_message', failure.userMessage!);
          }
        },
      );
    } else {
      await Sentry.captureMessage(
        '${failure.runtimeType}: ${failure.code}',
        level: SentryLevel.warning,
        withScope: (scope) {
          scope.setTag('failure_code', failure.code);
        },
      );
    }
    if (kDebugMode) {
      debugPrint('[Logger] failure ${failure.code}${cause != null ? ' cause=$cause' : ''}');
    }
  }

  @override
  Future<void> captureException(Object error, [StackTrace? stackTrace]) async {
    await Sentry.captureException(error, stackTrace: stackTrace);
    if (kDebugMode) debugPrint('[Logger] exception: $error');
  }

  @override
  Future<void> log(LogLevel level, String message, {Map<String, Object?>? extra}) async {
    final sentryLevel = switch (level) {
      LogLevel.debug => SentryLevel.debug,
      LogLevel.info => SentryLevel.info,
      LogLevel.warning => SentryLevel.warning,
      LogLevel.error => SentryLevel.error,
    };
    await Sentry.captureMessage(
      message,
      level: sentryLevel,
      withScope: (scope) {
        if (extra != null) {
          for (final entry in extra.entries) {
            scope.setExtra(entry.key, entry.value);
          }
        }
      },
    );
    if (kDebugMode) debugPrint('[Logger] ${level.name}: $message');
  }

  @override
  void breadcrumb(String message, {String? category, Map<String, Object?>? data}) {
    Sentry.addBreadcrumb(Breadcrumb(
      message: message,
      category: category,
      data: data,
    ));
  }

  @override
  Future<void> setUser({String? id, String? email}) async {
    await Sentry.configureScope((scope) {
      if (id == null && email == null) {
        scope.setUser(null);
      } else {
        scope.setUser(SentryUser(id: id, email: email));
      }
    });
  }
}
