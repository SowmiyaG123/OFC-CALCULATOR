import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';

import 'root_auth_gate.dart';
import 'screens/auth/reset_password_page.dart';
import 'screens/auth/login_page.dart';

// ✅ REQUIRED for navigation from deep link
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local storage
  await Hive.initFlutter();
  await Hive.openBox('diagram_history');

  // Supabase init (PKCE is correct)
  await Supabase.initialize(
    url: 'https://gmzlyasleyrsyphdasqk.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdtemx5YXNsZXlyc3lwaGRhc3FrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE2MzU0NzIsImV4cCI6MjA3NzIxMTQ3Mn0.8YaT2clc4LRP6R-IpxGx5DC88ibNzlPXRP7sLYv6hVI',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // ✅ DEEPLINK HANDLER (PASSWORD RECOVERY)
  _setupDeepLinkListener();

  runApp(const MyApp());
}

/// 🔥 DEEP LINK LISTENER - Handles both app launch and runtime links
void _setupDeepLinkListener() {
  final appLinks = AppLinks();

  // Handle deep link when app is ALREADY RUNNING
  appLinks.uriLinkStream.listen((Uri uri) async {
    debugPrint('🔗 DEEPLINK RECEIVED (runtime): $uri');
    await _handleDeepLink(uri);
  });

  // Handle deep link when app is LAUNCHED from link
  appLinks.getInitialAppLink().then((Uri? uri) async {
    if (uri != null) {
      debugPrint('🔗 DEEPLINK RECEIVED (launch): $uri');
      await _handleDeepLink(uri);
    }
  });
}

/// 🔥 PROCESS DEEP LINK
Future<void> _handleDeepLink(Uri uri) async {
  debugPrint('🔍 Processing URI: $uri');
  debugPrint('🔍 Query params: ${uri.queryParameters}');

  // Check if this is a password recovery link
  if (uri.queryParameters.containsKey('type') &&
      uri.queryParameters['type'] == 'recovery') {
    try {
      debugPrint('🔑 Recovery link detected, exchanging code for session...');

      // 🔑 Exchange recovery code for session
      final response = await Supabase.instance.client.auth
          .exchangeCodeForSession(uri.toString());

      debugPrint('✅ Session established: ${response.session != null}');

      // Small delay to ensure navigation is ready
      await Future.delayed(const Duration(milliseconds: 300));

      // ➜ Navigate to reset password screen
      navigatorKey.currentState?.pushReplacementNamed('/reset-password');
    } catch (e) {
      debugPrint('❌ Error handling recovery link: $e');
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // ✅ IMPORTANT
      debugShowCheckedModeBanner: false,
      title: 'OFC-CAL',
      theme: ThemeData(useMaterial3: true),

      // ✅ Routes required for recovery flow
      routes: {
        '/login': (_) => const LoginPage(),
        '/reset-password': (_) => const ResetPasswordPage(),
      },

      home: const RootAuthGate(),
    );
  }
}
