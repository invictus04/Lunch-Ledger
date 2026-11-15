import '../config/app_config.dart';
import '../utils/app_logger.dart';

/// Represents a row in `public.users`, including space-join cooldown metadata.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    this.lastLeftSpaceAt,
    required this.createdAt,
  });

  final String id;
  final String fullName;
  final String? avatarUrl;
  final DateTime? lastLeftSpaceAt;
  final DateTime createdAt;

  DateTime? get cooldownEndsAt =>
      lastLeftSpaceAt?.add(AppConfig.spaceJoinCooldown);

  Duration cooldownRemainingAt(DateTime now) {
    final endsAt = cooldownEndsAt;
    if (endsAt == null) return Duration.zero;
    final diff = endsAt.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  bool isCooldownActiveAt(DateTime now) =>
      cooldownRemainingAt(now) > Duration.zero;

  String get displayName =>
      fullName.trim().isEmpty ? 'Colleague' : fullName.trim();

  String get initials {
    final parts = displayName
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return AppLogger.parseJson('UserProfile', json, () {
      return UserProfile(
        id: json['id'] as String,
        fullName: (json['full_name'] as String?) ?? '',
        avatarUrl: json['avatar_url'] as String?,
        lastLeftSpaceAt: json['last_left_space_at'] != null
            ? DateTime.parse(json['last_left_space_at'] as String).toLocal()
            : null,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String).toLocal()
            : DateTime.now(),
      );
    });
  }

  UserProfile copyWith({
    String? fullName,
    String? avatarUrl,
    DateTime? lastLeftSpaceAt,
  }) {
    return UserProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastLeftSpaceAt: lastLeftSpaceAt ?? this.lastLeftSpaceAt,
      createdAt: createdAt,
    );
  }
}

