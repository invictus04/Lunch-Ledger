import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

import '../utils/app_logger.dart';

/// Application-wide constants, `.env` configuration, and INR/date helpers.
class AppConfig {
  const AppConfig._();

  static const String appName = 'Lunch Ledger';

  static String _readEnv(String key) {
    if (!dotenv.isInitialized) return '';
    return (dotenv.maybeGet(key) ?? '').trim();
  }

  static String get supabaseUrl => _readEnv('SUPABASE_URL');


  static String get supabasePublishableKey =>
      _readEnv('SUPABASE_PUBLISHABLE_KEY');

  static String get supabaseKey => supabasePublishableKey;

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Required cooling period after leaving a Space before joining another.
  static const Duration spaceJoinCooldown = Duration(days: 2);

  static const int defaultCutoffHour = 11;
  static const int defaultCutoffMinute = 0;

  static final NumberFormat _inrWhole = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final NumberFormat _inrDecimal = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  /// Formats [amount] in INR (`₹`), omitting `.00` for whole numbers.
  static String formatInr(num amount) {
    final rounded = (amount * 100).round() / 100;
    if ((rounded - rounded.truncateToDouble()).abs() < 0.001) {
      return _inrWhole.format(rounded.round());
    }
    return _inrDecimal.format(rounded);
  }

  /// Formats a local calendar date as `YYYY-MM-DD` for Postgres `date` columns.
  static String formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Parses a `YYYY-MM-DD` string into a local date-only [DateTime].
  static DateTime parseDateKey(String raw) {
    final parts = raw.trim().split('-');
    if (parts.length != 3) {
      AppLogger.error('AppConfig', 'Invalid date key format: "$raw"');
      throw FormatException('Invalid date key format: $raw');
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      AppLogger.error('AppConfig', 'Non-numeric date key: "$raw"');
      throw FormatException('Invalid numeric date key: $raw');
    }
    return DateTime(year, month, day);
  }

  /// Parses Postgres `time` (`HH:mm:ss` or `HH:mm`) into `(hour, minute)`.
  static ({int hour, int minute}) parseSqlTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return (hour: defaultCutoffHour, minute: defaultCutoffMinute);
    }
    final parts = raw.trim().split(':');
    final parsedHour = int.tryParse(parts[0]);
    final parsedMinute = parts.length > 1 ? int.tryParse(parts[1]) : 0;
    if (parsedHour == null || parsedMinute == null) {
      AppLogger.warn(
        'AppConfig',
        'Malformed SQL cutoff time "$raw"; falling back to default cutoff.',
      );
    }
    final hour = parsedHour ?? defaultCutoffHour;
    final minute = parsedMinute ?? defaultCutoffMinute;
    return (hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  static String formatSqlTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  static String formatCutoffDisplay(int hour, int minute) {
    final dt = DateTime(2026, 1, 1, hour, minute);
    return DateFormat('h:mm a').format(dt);
  }

  static String formatDurationCompact(Duration duration) {
    if (duration <= Duration.zero) {
      return '0m';
    }
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m';
    }
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    final seconds = duration.inSeconds.remainder(60);
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }
}

