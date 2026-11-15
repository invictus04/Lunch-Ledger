import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../utils/app_logger.dart';

/// Parsed error information, including structured 2-day cooldown timestamps.
class AppFailure implements Exception {
  const AppFailure(this.message, {this.cooldownUnlockAt});

  final String message;
  final DateTime? cooldownUnlockAt;

  @override
  String toString() => message;
}

/// Converts Supabase Auth and Postgres exceptions into readable messages.
class SupabaseErrorMapper {
  const SupabaseErrorMapper._();

  static const String _cooldownPrefix = 'COOLDOWN_ACTIVE:';

  static AppFailure map(Object error) {
    if (error is AppFailure) return error;

    if (error is AuthException) {
      return AppFailure(error.message);
    }

    if (error is PostgrestException) {
      final raw = error.message.trim();
      final idx = raw.indexOf(_cooldownPrefix);
      if (idx != -1) {
        final rawIso = raw.substring(idx + _cooldownPrefix.length).trim();
        final unlockAt = DateTime.tryParse(rawIso)?.toLocal();
        if (unlockAt != null) {
          final remaining = unlockAt.difference(DateTime.now());
          final formatted = AppConfig.formatDurationCompact(remaining);
          return AppFailure(
            '2-day cooling period active. You can join another space in $formatted.',
            cooldownUnlockAt: unlockAt,
          );
        }
        AppLogger.warn(
          'ErrorMapper',
          'Could not parse COOLDOWN_ACTIVE timestamp from "$rawIso".',
        );
        return const AppFailure(
          '2-day cooling period active. Please wait before joining another space.',
        );
      }
      return AppFailure(raw.isEmpty ? 'Database request failed.' : raw);
    }

    return AppFailure(error.toString());
  }
}

