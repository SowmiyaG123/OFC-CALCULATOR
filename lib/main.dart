import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/auth_service.dart';
import 'screens/auth/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // Web: Use FirebaseOptions from your Firebase JS config
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCIeSeTm_BO9meGKASqVVhyhnCFgbbraq0",
        authDomain: "ofc-calculator.firebaseapp.com",
        projectId: "ofc-calculator",
        storageBucket: "ofc-calculator.firebasestorage.app",
        messagingSenderId: "685316942347",
        appId: "1:685316942347:web:9a6e1eb97d02cbc37c750e",
        measurementId: "G-7KN67XC6GK", // Optional
      ),
    );
  } else {
    // Mobile platforms (Android/iOS)
    await Firebase.initializeApp();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OFC-CAL',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginPage(),
    );
  }
}
