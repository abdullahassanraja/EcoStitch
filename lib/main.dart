import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'screens/home_screen.dart';
import 'screens/capture_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure system status bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Initialize Supabase with project URL and public anon key
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  // Sign in anonymously on app start if there is no active session
  // This provides every user with a real auth.uid() without requiring a login screen yet.
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) {
    try {
      final authResponse = await Supabase.instance.client.auth.signInAnonymously();
      if (kDebugMode) {
        print('[EcoStitch] Anonymous session established for user: ${authResponse.user?.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[EcoStitch] Anonymous sign-in warning: $e');
      }
    }
  } else {
    if (kDebugMode) {
      print('[EcoStitch] Active session found for user: ${session.user.id}');
    }
  }

  runApp(const EcoStitchApp());
}

/// GoRouter configuration for simple, robust navigation
final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const HomeScreen();
      },
    ),
    GoRoute(
      path: '/capture',
      builder: (BuildContext context, GoRouterState state) {
        return const CaptureScreen();
      },
    ),
  ],
);

/// Root Application Widget
class EcoStitchApp extends StatelessWidget {
  const EcoStitchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EcoStitch',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: _router,
    );
  }
}
