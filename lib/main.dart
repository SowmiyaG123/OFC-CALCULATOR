import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Screens
import 'screens/auth/login_page.dart';
import 'screens/main_app/main_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Hive safely
  try {
    await Hive.initFlutter();

    if (!Hive.isBoxOpen('diagram_history')) {
      await Hive.openBox('diagram_history');
      debugPrint("✅ Hive box 'diagram_history' opened successfully.");
    } else {
      debugPrint("ℹ️ Hive box 'diagram_history' already open.");
    }
  } catch (e) {
    debugPrint("❌ Hive initialization failed: $e");
  }

  // ✅ Initialize Supabase safely
  try {
    await Supabase.initialize(
      url: 'https://gmzlyasleyrsyphdasqk.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdtemx5YXNsZXlyc3lwaGRhc3FrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE2MzU0NzIsImV4cCI6MjA3NzIxMTQ3Mn0.8YaT2clc4LRP6R-IpxGx5DC88ibNzlPXRP7sLYv6hVI',
    );
    debugPrint("✅ Supabase initialized successfully.");
  } catch (e) {
    debugPrint("❌ Supabase initialization failed: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OFC-CAL',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/dashboard': (context) => const MainDashboard(), // 👈 Dashboard route
      },
    );
  }
}
