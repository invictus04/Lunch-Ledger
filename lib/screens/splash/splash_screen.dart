import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';
import '../auth/auth_gate.dart';

/// Branded splash screen displaying [assets/Lunch_ledger.png] before routing
/// into [AuthGate].
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.duration = const Duration(milliseconds: 1600),
  });

  final Duration duration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // Matches the exact canvas background (#FAFAF8) of assets/Lunch_ledger.png
  // so the artwork blends edge-to-edge on launch.
  static const Color _canvasBg = Color(0xFFFAFAF8);
  static const String _logoAsset = 'assets/Lunch_ledger.png';

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  Timer? _navTimer;
  bool _hasPrecached = false;

  @override
  void initState() {
    super.initState();
    AppLogger.nav('Entered SplashScreen', scope: 'SplashScreen');

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();

    _navTimer = Timer(widget.duration, _navigateToAuthGate);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasPrecached) return;
    _hasPrecached = true;
    unawaited(
      precacheImage(const AssetImage(_logoAsset), context).catchError((
        Object err,
        StackTrace st,
      ) {
        AppLogger.error(
          'SplashScreen',
          'Failed to precache splash asset $_logoAsset',
          error: err,
          stackTrace: st,
        );
      }),
    );
  }

  void _navigateToAuthGate() {
    if (!mounted) return;
    AppLogger.nav('SplashScreen -> AuthGate', scope: 'SplashScreen');
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: '/auth-gate'),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AuthGate(),
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvasBg,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Image.asset(
                      _logoAsset,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      semanticLabel: 'Lunch Ledger',
                      errorBuilder: (context, error, stackTrace) {
                        AppLogger.error(
                          'SplashScreen',
                          'Failed to load splash asset $_logoAsset',
                          error: error,
                          stackTrace: stackTrace,
                        );
                        return const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bento_rounded,
                              size: 64,
                              color: AppTheme.primary,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Lunch Ledger',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.ink,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 36,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

