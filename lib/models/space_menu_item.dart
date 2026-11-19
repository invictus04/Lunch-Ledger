import '../utils/app_logger.dart';

/// A customizable meal item belonging to a Space (e.g. "Full Tiffin with 4 Roti").
class SpaceMenuItem {
  const SpaceMenuItem({
    required this.id,
    required this.spaceId,
    required this.name,
    required this.price,
    required this.isActive,
    required this.sortOrder,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String spaceId;
  final String name;
  final double price;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory SpaceMenuItem.fromJson(Map<String, dynamic> json) {
    return AppLogger.parseJson('SpaceMenuItem', json, () {
      return SpaceMenuItem(
        id: json['id'] as String,
        spaceId: json['space_id'] as String,
        name: (json['name'] as String?)?.trim() ?? '',
        price: (json['price'] as num).toDouble(),
        isActive: (json['is_active'] as bool?) ?? true,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String).toLocal()
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String).toLocal()
            : null,
      );
    });
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'space_id': spaceId,
        'name': name,
        'price': price,
        'is_active': isActive,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };

  SpaceMenuItem copyWith({
    String? id,
    String? spaceId,
    String? name,
    double? price,
    bool? isActive,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SpaceMenuItem(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      name: name ?? this.name,
      price: price ?? this.price,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpaceMenuItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
