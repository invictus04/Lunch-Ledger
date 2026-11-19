import '../config/app_config.dart';
import '../utils/app_logger.dart';
import 'tiffin_log.dart';

/// Represents a shared office tiffin group (`public.spaces`).
class Space {
  const Space({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.leaderId,
    required this.priceFull,
    required this.priceHalf,
    required this.cutoffHour,
    required this.cutoffMinute,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String inviteCode;
  final String leaderId;
  final double priceFull;
  final double priceHalf;
  final int cutoffHour;
  final int cutoffMinute;
  final DateTime createdAt;

  String get cutoffDisplay =>
      AppConfig.formatCutoffDisplay(cutoffHour, cutoffMinute);

  String get cutoffSql => AppConfig.formatSqlTime(cutoffHour, cutoffMinute);

  DateTime cutoffDateTimeOn(DateTime date) =>
      DateTime(date.year, date.month, date.day, cutoffHour, cutoffMinute);

  bool isPastCutoffAt(DateTime now) => now.isAfter(cutoffDateTimeOn(now));

  Duration timeUntilCutoffAt(DateTime now) {
    final diff = cutoffDateTimeOn(now).difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  double priceForType(TiffinType type) {
    switch (type) {
      case TiffinType.full:
        return priceFull;
      case TiffinType.half:
        return priceHalf;
      case TiffinType.skip:
      case TiffinType.custom:
        return 0;
    }
  }

  factory Space.fromJson(Map<String, dynamic> json) {
    return AppLogger.parseJson('Space', json, () {
      final cutoff = AppConfig.parseSqlTime(json['cutoff_time'] as String?);
      return Space(
        id: json['id'] as String,
        name: json['name'] as String,
        inviteCode: json['invite_code'] as String,
        leaderId: json['leader_id'] as String,
        priceFull: (json['price_full'] as num).toDouble(),
        priceHalf: (json['price_half'] as num).toDouble(),
        cutoffHour: cutoff.hour,
        cutoffMinute: cutoff.minute,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String).toLocal()
            : DateTime.now(),
      );
    });
  }

  Space copyWith({
    String? name,
    String? leaderId,
    double? priceFull,
    double? priceHalf,
    int? cutoffHour,
    int? cutoffMinute,
  }) {
    return Space(
      id: id,
      name: name ?? this.name,
      inviteCode: inviteCode,
      leaderId: leaderId ?? this.leaderId,
      priceFull: priceFull ?? this.priceFull,
      priceHalf: priceHalf ?? this.priceHalf,
      cutoffHour: cutoffHour ?? this.cutoffHour,
      cutoffMinute: cutoffMinute ?? this.cutoffMinute,
      createdAt: createdAt,
    );
  }
}

