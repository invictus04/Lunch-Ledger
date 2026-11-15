import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../utils/app_logger.dart';
import 'supabase_error_mapper.dart';

/// Handles Phase 1 Email/Password authentication and `public.users` profile ops.
class AuthService {
  AuthService(this._client);

  static const _scope = 'AuthService';
  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await AppLogger.traceAsync(
        _scope,
        'signInWithEmail',
        () => _client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        ),
        describeResult: (res) => 'userId=${res.user?.id}',
      );
    } catch (e) {
      throw SupabaseErrorMapper.map(e);
    }
  }

  Future<AuthResponse> signUpWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      return await AppLogger.traceAsync(
        _scope,
        'signUpWithEmail',
        () => _client.auth.signUp(
          email: email.trim(),
          password: password,
          data: {'full_name': fullName.trim()},
        ),
        describeResult: (res) =>
            'userId=${res.user?.id}, hasSession=${res.session != null}',
      );
    } catch (e) {
      throw SupabaseErrorMapper.map(e);
    }
  }

  Future<void> signOut() async {
    try {
      await AppLogger.traceAsync(
        _scope,
        'signOut',
        () => _client.auth.signOut(),
      );
    } catch (e) {
      throw SupabaseErrorMapper.map(e);
    }
  }

  Future<UserProfile?> fetchCurrentProfile() async {
    final user = currentUser;
    if (user == null) {
      AppLogger.info(_scope, 'fetchCurrentProfile: no authenticated session.');
      return null;
    }

    try {
      return await AppLogger.traceAsync(
        _scope,
        'fetchCurrentProfile(userId=${user.id})',
        () async {
          final row = await _client
              .from('users')
              .select()
              .eq('id', user.id)
              .maybeSingle();

          if (row == null) {
            AppLogger.warn(
              _scope,
              'No public.users row found for userId=${user.id}; using auth metadata fallback.',
            );
            final fallbackName =
                (user.userMetadata?['full_name'] as String?)?.trim() ??
                (user.email?.split('@').first ?? 'Colleague');
            return UserProfile(
              id: user.id,
              fullName: fallbackName,
              createdAt: DateTime.now(),
            );
          }
          return UserProfile.fromJson(row);
        },
        describeResult: (p) => 'name=${p?.displayName}',
      );
    } catch (e) {
      throw SupabaseErrorMapper.map(e);
    }
  }

  Future<UserProfile> updateFullName(String fullName) async {
    final user = currentUser;
    if (user == null) {
      AppLogger.warn(_scope, 'updateFullName aborted: user is not authenticated.');
      throw const AppFailure('Not authenticated.');
    }

    try {
      return await AppLogger.traceAsync(
        _scope,
        'updateFullName(userId=${user.id})',
        () async {
          final row = await _client
              .from('users')
              .update({'full_name': fullName.trim()})
              .eq('id', user.id)
              .select()
              .single();
          return UserProfile.fromJson(row);
        },
        describeResult: (p) => 'name=${p.displayName}',
      );
    } catch (e) {
      throw SupabaseErrorMapper.map(e);
    }
  }
}

