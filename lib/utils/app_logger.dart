import 'package:flutter/material.dart';

/// Structured console logger for async operations, screen navigation,
/// Realtime events, parsing guards, and catch-block diagnostics.
class AppLogger {
  const AppLogger._();

  static String _timestamp() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  static void _emit(
    String tag,
    String scope,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    debugPrint('[${_timestamp()}] [$tag] [$scope] $message');
    if (error != null) {
      debugPrint('  ↳ error: $error');
    }
    if (stackTrace != null) {
      debugPrint('  ↳ stack: $stackTrace');
    }
  }

  static void info(String scope, String message) {
    _emit('INFO', scope, message);
  }

  static void nav(String message, {String scope = 'Navigation'}) {
    _emit('NAV', scope, message);
  }

  static void realtime(String scope, String message, {Object? error}) {
    _emit('REALTIME', scope, message, error: error);
  }

  static void warn(String scope, String message, {Object? error}) {
    _emit('WARN', scope, message, error: error);
  }

  static void error(
    String scope,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _emit('ERROR', scope, message, error: error, stackTrace: stackTrace);
  }

  /// Wraps an async operation to log start, elapsed duration on completion,
  /// and full error + stack trace if an exception is thrown.
  static Future<T> traceAsync<T>(
    String scope,
    String operation,
    Future<T> Function() action, {
    String Function(T result)? describeResult,
  }) async {
    final stopwatch = Stopwatch()..start();
    _emit('ASYNC', scope, '▶ $operation');
    try {
      final result = await action();
      stopwatch.stop();
      final detail = describeResult != null
          ? ' (${describeResult(result)})'
          : '';
      _emit(
        'ASYNC',
        scope,
        '✔ $operation completed in ${stopwatch.elapsedMilliseconds}ms$detail',
      );
      return result;
    } catch (err, st) {
      stopwatch.stop();
      error(
        scope,
        '✖ $operation failed after ${stopwatch.elapsedMilliseconds}ms',
        error: err,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Guards model JSON deserialization (a common failure point when backend
  /// payloads change) and logs failing keys/types before rethrowing.
  static T parseJson<T>(
    String modelName,
    Map<String, dynamic> json,
    T Function() parser,
  ) {
    try {
      return parser();
    } catch (err, st) {
      error(
        'Parser.$modelName',
        'Failed to parse JSON with keys=${json.keys.toList()}',
        error: err,
        stackTrace: st,
      );
      rethrow;
    }
  }
}

/// Logs imperative [Navigator] transitions (dialogs, pickers, routes).
class AppNavigatorObserver extends NavigatorObserver {
  String _describeRoute(Route<dynamic>? route) {
    if (route == null) return 'null';
    final name = route.settings.name;
    return name != null && name.isNotEmpty
        ? '$name (${route.runtimeType})'
        : '${route.runtimeType}';
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    AppLogger.nav(
      'PUSH ${_describeRoute(route)} <- ${_describeRoute(previousRoute)}',
      scope: 'Navigator',
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    AppLogger.nav(
      'POP ${_describeRoute(route)} -> ${_describeRoute(previousRoute)}',
      scope: 'Navigator',
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    AppLogger.nav(
      'REPLACE ${_describeRoute(oldRoute)} -> ${_describeRoute(newRoute)}',
      scope: 'Navigator',
    );
  }
}
