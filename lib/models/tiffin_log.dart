import '../config/app_config.dart';
import '../utils/app_logger.dart';

/// Meal option logged by a user for a given day.
enum TiffinType {
  full('full', 'Full'),
  half('half', 'Half'),
  skip('skip', 'Skip'),
  custom('custom', 'Custom');

  const TiffinType(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static TiffinType fromDb(String value) {
    for (final t in TiffinType.values) {
      if (t.dbValue == value) return t;
    }
    AppLogger.warn(
      'Parser.TiffinType',
      'Unknown tiffin type "$value" from DB; defaulting to skip.',
    );
    return TiffinType.skip;
  }
}

/// Daily meal entry in `public.tiffin_logs` with snapshotted `cost`.
class TiffinLog {
  const TiffinLog({
    required this.id,
    required this.userId,
    required this.spaceId,
    required this.logDate,
    required this.type,
    required this.cost,
    required this.createdAt,
    required this.updatedAt,
    this.menuItemId,
    this.itemName,
  });

  final String id;
  final String userId;
  final String spaceId;
  final DateTime logDate;
  final TiffinType type;
  final double cost;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? menuItemId;
  final String? itemName;

  String get dateKey => AppConfig.formatDateKey(logDate);

  String get displayLabel {
    if (itemName != null && itemName!.trim().isNotEmpty) {
      return itemName!.trim();
    }
    return type.label;
  }

  factory TiffinLog.fromJson(Map<String, dynamic> json) {
    return AppLogger.parseJson('TiffinLog', json, () {
      return TiffinLog(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        spaceId: json['space_id'] as String,
        logDate: AppConfig.parseDateKey(json['log_date'] as String),
        type: TiffinType.fromDb(json['type'] as String),
        cost: (json['cost'] as num).toDouble(),
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String).toLocal()
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String).toLocal()
            : DateTime.now(),
        menuItemId: json['menu_item_id'] as String?,
        itemName: json['item_name'] as String?,
      );
    });
  }
}

