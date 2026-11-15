import 'dart:ui';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/tiffin_log.dart';
import '../utils/app_logger.dart';
import 'supabase_error_mapper.dart';

/// Handles daily tiffin logging, monthly history queries, and Realtime sync.
class TiffinService {
  TiffinService(this._client);

  static const _scope = 'TiffinService';
  final SupabaseClient _client;

  Future<TiffinLog> upsertDailyLog({
    required String userId,
    required String spaceId,
    required DateTime date,
    required TiffinType type,
  }) async {
    final dateKey = AppConfig.formatDateKey(date);
    try {
      return await AppLogger.traceAsync(
        _scope,
        'upsertDailyLog(date=$dateKey, type=${type.dbValue})',
        () async {
          final row = await _client
              .from('tiffin_logs')
              .upsert(
                {
                  'user_id': userId,
                  'space_id': spaceId,
                  'log_date': dateKey,
                  'type': type.dbValue,
                },
                onConflict: 'user_id,space_id,log_date',
              )
              .select()
              .single();
          return TiffinLog.fromJson(row);
        },
        describeResult: (log) => 'id=${log.id}, cost=${log.cost}',
      );
    } catch (e) {
      throw SupabaseErrorMapper.map(e);
    }
  }

  Future<List<TiffinLog>> fetchLogsForDate({
    required String spaceId,
    required DateTime date,
  }) async {
    final dateKey = AppConfig.formatDateKey(date);
    try {
      return await AppLogger.traceAsync(
        _scope,
        'fetchLogsForDate(spaceId=$spaceId, date=$dateKey)',
        () async {
          final rows = await _client
              .from('tiffin_logs')
              .select()
              .eq('space_id', spaceId)
              .eq('log_date', dateKey);
          return rows.map((e) => TiffinLog.fromJson(e)).toList();
        },
        describeResult: (logs) => '${logs.length} logs',
      );
    } catch (e) {
      throw SupabaseErrorMapper.map(e);
    }
  }

  Future<List<TiffinLog>> fetchSpaceMonthLogs({
    required String spaceId,
    required DateTime month,
  }) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final startKey = AppConfig.formatDateKey(start);
    final endKey = AppConfig.formatDateKey(end);

    try {
      return await AppLogger.traceAsync(
        _scope,
        'fetchSpaceMonthLogs(spaceId=$spaceId, range=$startKey..$endKey)',
        () async {
          final rows = await _client
              .from('tiffin_logs')
              .select()
              .eq('space_id', spaceId)
              .gte('log_date', startKey)
              .lte('log_date', endKey)
              .order('log_date', ascending: false);

          return rows.map((e) => TiffinLog.fromJson(e)).toList();
        },
        describeResult: (logs) => '${logs.length} logs',
      );
    } catch (e) {
      throw SupabaseErrorMapper.map(e);
    }
  }

  RealtimeChannel subscribeToSpace({
    required String spaceId,
    required VoidCallback onDataChanged,
  }) {
    final topic = 'space-$spaceId';
    AppLogger.realtime(_scope, 'Subscribing to Realtime channel "$topic"');
    final channel = _client.channel(topic);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tiffin_logs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'space_id',
            value: spaceId,
          ),
          callback: (payload) {
            AppLogger.realtime(
              _scope,
              'tiffin_logs ${payload.eventType.name} received for space=$spaceId',
            );
            onDataChanged();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'space_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'space_id',
            value: spaceId,
          ),
          callback: (payload) {
            AppLogger.realtime(
              _scope,
              'space_members ${payload.eventType.name} received for space=$spaceId',
            );
            onDataChanged();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'spaces',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: spaceId,
          ),
          callback: (payload) {
            AppLogger.realtime(
              _scope,
              'spaces ${payload.eventType.name} received for space=$spaceId',
            );
            onDataChanged();
          },
        )
        .subscribe((status, error) {
          if (error != null) {
            AppLogger.error(
              'Realtime',
              'Channel "$topic" status=${status.name}',
              error: error,
            );
          } else {
            AppLogger.realtime(_scope, 'Channel "$topic" status=${status.name}');
          }
        });

    return channel;
  }

  Future<void> unsubscribe(RealtimeChannel channel) async {
    await AppLogger.traceAsync(
      _scope,
      'removeChannel',
      () => _client.removeChannel(channel),
    );
  }
}

