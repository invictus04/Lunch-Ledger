import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/space.dart';
import '../models/space_member.dart';
import '../models/user_profile.dart';
import '../utils/app_logger.dart';
import 'supabase_error_mapper.dart';

/// Active Space + current user's membership and profile snapshot.
class ActiveSpaceContext {
  const ActiveSpaceContext({
    required this.profile,
    this.space,
    this.membership,
  });

  final UserProfile profile;
  final Space? space;
  final SpaceMember? membership;

  bool get hasActiveSpace => space != null && membership != null;
  bool get isLeader =>
      space != null && space!.leaderId == profile.id;
}

/// Manages Space creation, joining (with 2-day cooldown), leaving, and settings.
class SpaceService {
  SpaceService(this._client);

  static const _scope = 'SpaceService';
  final SupabaseClient _client;

  Map<String, dynamic> _unwrapRpcMap(dynamic data, String rpcName) {
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (data is List && data.isNotEmpty && data.first is Map) {
      AppLogger.warn(
        _scope,
        'RPC "$rpcName" returned a List payload; unwrapping first row.',
      );
      return Map<String, dynamic>.from(data.first as Map);
    }
    AppLogger.error(
      _scope,
      'RPC "$rpcName" returned unexpected payload type: ${data.runtimeType}',
    );
    throw FormatException('Unexpected $rpcName response shape.');
  }

  Future<ActiveSpaceContext> fetchActiveContext(UserProfile profile) async {
    try {
      return await AppLogger.traceAsync(
        _scope,
        'fetchActiveContext(userId=${profile.id})',
        () async {
          final row = await _client
              .from('space_members')
              .select('*, spaces(*)')
              .eq('user_id', profile.id)
              .maybeSingle();

          if (row == null || row['spaces'] == null) {
            return ActiveSpaceContext(profile: profile);
          }

          final space = Space.fromJson(row['spaces'] as Map<String, dynamic>);
          final membership = SpaceMember(
            id: row['id'] as String,
            spaceId: row['space_id'] as String,
            userId: row['user_id'] as String,
            role: (row['role'] as String?) ?? 'member',
            joinedAt: row['joined_at'] != null
                ? DateTime.parse(row['joined_at'] as String).toLocal()
                : DateTime.now(),
            user: profile,
          );

          return ActiveSpaceContext(
            profile: profile,
            space: space,
            membership: membership,
          );
        },
        describeResult: (ctx) => ctx.hasActiveSpace
            ? 'spaceId=${ctx.space!.id}, role=${ctx.membership!.role}'
            : 'no active space',
      );
    } catch (e) {
      throw SupabaseErrorMapper.map(e);
    }
  }

  Future<Space> createSpace({
    required String name,
    required double priceFull,
    required double priceHalf,
    required int cutoffHour,
    required int cutoffMinute,
  }) async {
    try {
      return await AppLogger.traceAsync(
        _scope,
        'rpc:create_space(name=${name.trim()})',
        () async {
          final data = await _client.rpc(
            'create_space',
            params: {
              'p_name': name.trim(),
              'p_price_full': priceFull,
              'p_price_half': priceHalf,
              'p_cutoff_time': AppConfig.formatSqlTime(cutoffHour, cutoffMinute),
            },
          );
          return Space.fromJson(_unwrapRpcMap(data, 'create_space'));
        },
        describeResult: (s) => 'spaceId=${s.id}, code=${s.inviteCode}',
      );
    } catch (e) {
      throw SupabaseErrorMapper.map(e);
    }
  }

  Future<Space> joinSpaceByCode(String inviteCode) async {
    try {
      return await AppLogger.traceAsync(
        _scope,
        'rpc:join_space_by_code(code=${inviteCode.trim()})',
        () async {
          final data = await _client.rpc(
            'join_space_by_code',
            params: {'p_invite_code': inviteCode.trim()},
          );
          return Space.fromJson(_unwrapRpcMap(data, 'join_space_by_code'));
        },
        describeResult: (s) => 'spaceId=${s.id}, name=${s.name}',
      );
    } catch (e) {
      throw SupabaseErrorMapper.map(e);
    }
  }

  Future<DateTime> leaveSpace() async {
    try {
      return await AppLogger.traceAsync(
        _scope,
        'rpc:leave_space',
        () async {
          final data = await _client.rpc('leave_space');
          if (data is! String) {
            AppLogger.error(
              _scope,
              'RPC "leave_space" returned non-string cooldown timestamp: ${data.runtimeType}',
            );
            throw const FormatException('Invalid leave_space cooldown timestamp.');
          }
          return DateTime.parse(data).toLocal();
        },
        describeResult: (until) => 'cooldownUntil=$until',
      );
    } catch (e) {
      throw SupabaseErrorMapper.map(e);
    }
  }

  Future<void> transferLeadership(String newLeaderId) async {
    try {
      await AppLogger.traceAsync(
        _scope,
        'rpc:transfer_leadership(newLeaderId=$newLeaderId)',
        () => _client.rpc(
          'transfer_leadership',
          params: {'p_new_leader_id': newLeaderId},
        ),
      );
    } catch (e) {
      throw SupabaseErrorMapper.map(e);
    }
  }

  Future<Space> updateSpaceSettings({
    required String spaceId,
    required double priceFull,
    required double priceHalf,
    required int cutoffHour,
    required int cutoffMinute,
  }) async {
    try {
      return await AppLogger.traceAsync(
        _scope,
        'updateSpaceSettings(spaceId=$spaceId)',
        () async {
          final row = await _client
              .from('spaces')
              .update({
                'price_full': priceFull,
                'price_half': priceHalf,
                'cutoff_time': AppConfig.formatSqlTime(cutoffHour, cutoffMinute),
              })
              .eq('id', spaceId)
              .select()
              .single();
          return Space.fromJson(row);
        },
        describeResult: (s) =>
            'full=${s.priceFull}, half=${s.priceHalf}, cutoff=${s.cutoffSql}',
      );
    } catch (e) {
      throw SupabaseErrorMapper.map(e);
    }
  }

  Future<List<SpaceMember>> fetchSpaceMembers(String spaceId) async {
    try {
      return await AppLogger.traceAsync(
        _scope,
        'fetchSpaceMembers(spaceId=$spaceId)',
        () async {
          final rows = await _client
              .from('space_members')
              .select('*, users(*)')
              .eq('space_id', spaceId)
              .order('joined_at', ascending: true);

          final members = rows
              .map((e) => SpaceMember.fromJson(e))
              .toList();

          members.sort((a, b) {
            if (a.isLeader != b.isLeader) return a.isLeader ? -1 : 1;
            return a.user.displayName.toLowerCase().compareTo(
              b.user.displayName.toLowerCase(),
            );
          });

          return members;
        },
        describeResult: (m) => '${m.length} members',
      );
    } catch (e) {
      throw SupabaseErrorMapper.map(e);
    }
  }
}

