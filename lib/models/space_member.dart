import '../utils/app_logger.dart';
import 'user_profile.dart';

/// Represents a user's membership in a Space (`public.space_members`).
class SpaceMember {
  const SpaceMember({
    required this.id,
    required this.spaceId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    required this.user,
  });

  final String id;
  final String spaceId;
  final String userId;
  final String role;
  final DateTime joinedAt;
  final UserProfile user;

  bool get isLeader => role == 'leader';

  factory SpaceMember.fromJson(Map<String, dynamic> json) {
    return AppLogger.parseJson('SpaceMember', json, () {
      final userJson = json['users'] as Map<String, dynamic>?;
      if (userJson == null) {
        AppLogger.warn(
          'Parser.SpaceMember',
          'Missing joined users payload for userId=${json['user_id']}; using fallback name.',
        );
      }
      return SpaceMember(
        id: json['id'] as String,
        spaceId: json['space_id'] as String,
        userId: json['user_id'] as String,
        role: (json['role'] as String?) ?? 'member',
        joinedAt: json['joined_at'] != null
            ? DateTime.parse(json['joined_at'] as String).toLocal()
            : DateTime.now(),
        user: userJson != null
            ? UserProfile.fromJson(userJson)
            : UserProfile(
                id: json['user_id'] as String,
                fullName: 'Colleague',
                createdAt: DateTime.now(),
              ),
      );
    });
  }
}

