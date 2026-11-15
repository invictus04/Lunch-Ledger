import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'screens/splash/splash_screen.dart';
import 'theme/app_theme.dart';
import 'utils/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.info('Boot', 'Starting ${AppConfig.appName}');

  try {
    await AppLogger.traceAsync(
      'Boot',
      'dotenv.load(.env)',
      () => dotenv.load(fileName: '.env', isOptional: true),
      describeResult: (_) =>
          'isSupabaseConfigured=${AppConfig.isSupabaseConfigured}',
    );
  } catch (err, st) {
    AppLogger.warn(
      'Boot',
      'Failed to load .env; falling back to setup notice if unconfigured.',
      error: err,
    );
    AppLogger.error('Boot', 'dotenv.load exception', error: err, stackTrace: st);
  }

  if (AppConfig.isSupabaseConfigured) {
    try {
      await AppLogger.traceAsync(
        'Boot',
        'Supabase.initialize',
        () => Supabase.initialize(
          url: AppConfig.supabaseUrl,
          publishableKey: AppConfig.supabaseKey,
        ),
      );
    } catch (err, st) {
      AppLogger.error(
        'Boot',
        'Supabase.initialize failed',
        error: err,
        stackTrace: st,
      );
    }
  } else {
    AppLogger.warn(
      'Boot',
      'Supabase credentials missing in .env; app will open setup notice.',
    );
  }

  runApp(const TiffinTrackerApp());
}

/// Root application widget for Lunch Ledger.
class TiffinTrackerApp extends StatelessWidget {
  const TiffinTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      navigatorObservers: [AppNavigatorObserver()],
      home: const SplashScreen(),
    );
  }
}
