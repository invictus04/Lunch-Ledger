import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import '../../services/auth_service.dart';
import '../../services/space_service.dart';
import '../../services/supabase_error_mapper.dart';
import '../../services/tiffin_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';
import '../gateway/space_gateway_screen.dart';
import '../main/main_shell.dart';
import 'auth_screen.dart';

/// Root flow coordinator routing users between:
///   1) Supabase configuration instructions (when env defines are missing)
///   2) [AuthScreen] (when signed out)
///   3) [SpaceGatewayScreen] (when signed in without an active Space)
///   4) [MainShell] (when signed in and assigned to an active Space)
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService _authService;
  late final SpaceService _spaceService;
  late final TiffinService _tiffinService;

  StreamSubscription<AuthState>? _authSub;
  Future<ActiveSpaceContext?>? _contextFuture;
  String? _lastLoggedRoute;

  @override
  void initState() {
    super.initState();
    if (!AppConfig.isSupabaseConfigured) {
      _logRoute('SetupNotice (Supabase unconfigured)');
      return;
    }

    final client = Supabase.instance.client;
    _authService = AuthService(client);
    _spaceService = SpaceService(client);
    _tiffinService = TiffinService(client);

    _reloadContext();
    _authSub = _authService.onAuthStateChange.listen((authState) {
      AppLogger.info(
        'AuthGate',
        'onAuthStateChange event=${authState.event.name}, hasSession=${authState.session != null}',
      );
      if (mounted) _reloadContext();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _logRoute(String routeLabel) {
    if (_lastLoggedRoute == routeLabel) return;
    _lastLoggedRoute = routeLabel;
    AppLogger.nav('AuthGate -> $routeLabel', scope: 'AuthGate');
  }

  void _reloadContext() {
    setState(() {
      _contextFuture = _loadActiveSpaceContext();
    });
  }

  Future<ActiveSpaceContext?> _loadActiveSpaceContext() async {
    return AppLogger.traceAsync(
      'AuthGate',
      'loadActiveSpaceContext',
      () async {
        final profile = await _authService.fetchCurrentProfile();
        if (profile == null) return null;
        return _spaceService.fetchActiveContext(profile);
      },
      describeResult: (ctx) => ctx == null
          ? 'unauthenticated'
          : (ctx.hasActiveSpace
              ? 'space=${ctx.space!.name} (${ctx.membership!.role})'
              : 'no active space'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isSupabaseConfigured) {
      return const _SupabaseSetupNotice();
    }

    return FutureBuilder<ActiveSpaceContext?>(
      future: _contextFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          final err = snapshot.error;
          final msg = err is AppFailure ? err.message : err.toString();
          AppLogger.error(
            'AuthGate',
            'Context resolution failed; showing retry screen',
            error: err,
            stackTrace: snapshot.stackTrace,
          );
          _logRoute('ErrorRetryScreen');
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 44,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      msg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.ink),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _reloadContext,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final activeContext = snapshot.data;
        if (activeContext == null) {
          _logRoute('AuthScreen');
          return AuthScreen(
            onSignIn: (email, password) => _authService.signInWithEmail(
              email: email,
              password: password,
            ),
            onSignUp: (fullName, email, password) async {
              final res = await _authService.signUpWithEmail(
                fullName: fullName,
                email: email,
                password: password,
              );
              if (res.session == null) {
                return 'Account created! Check your email to confirm, then sign in.';
              }
              return null;
            },
          );
        }

        if (!activeContext.hasActiveSpace) {
          _logRoute(
            'SpaceGatewayScreen(cooldownActive=${activeContext.profile.isCooldownActiveAt(DateTime.now())})',
          );
          return SpaceGatewayScreen(
            profile: activeContext.profile,
            onJoinSpace: _spaceService.joinSpaceByCode,
            onCreateSpace: ({
              required name,
              required priceFull,
              required priceHalf,
              required cutoffHour,
              required cutoffMinute,
            }) => _spaceService.createSpace(
              name: name,
              priceFull: priceFull,
              priceHalf: priceHalf,
              cutoffHour: cutoffHour,
              cutoffMinute: cutoffMinute,
            ),
            onSpaceEntered: _reloadContext,
            onSignOut: _authService.signOut,
          );
        }

        _logRoute(
          'MainShell(space=${activeContext.space!.name}, role=${activeContext.membership!.role})',
        );
        return MainShell(
          key: ValueKey(activeContext.space!.id),
          initialContext: activeContext,
          authService: _authService,
          spaceService: _spaceService,
          tiffinService: _tiffinService,
          onSpaceLeft: _reloadContext,
        );
      },
    );
  }
}

class _SupabaseSetupNotice extends StatelessWidget {
  const _SupabaseSetupNotice();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Supabase Not Configured',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Run the SQL migration in supabase/migrations/001_initial_schema.sql '
                    'and add your project credentials to the root .env file:\n\n'
                    'SUPABASE_URL=https://YOUR_PROJECT.supabase.co\n'
                    'SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppTheme.mutedInk,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

