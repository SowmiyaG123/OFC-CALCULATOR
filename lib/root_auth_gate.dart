import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth/login_page.dart';
import 'screens/auth/reset_password_page.dart';
import 'screens/main_app/main_dashboard.dart';
import 'screens/auth/email_verified_page.dart';

class RootAuthGate extends StatefulWidget {
  const RootAuthGate({super.key});

  @override
  State<RootAuthGate> createState() => _RootAuthGateState();
}

class _RootAuthGateState extends State<RootAuthGate> {
  final SupabaseClient _client = Supabase.instance.client;

  Session? _session;
  bool _isRecovery = false;
  bool _isEmailVerifiedPage = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final uri = Uri.base;

    // 🔐 PASSWORD RESET FLOW
    if (uri.queryParameters['type'] == 'recovery') {
      setState(() {
        _isRecovery = true;
        _ready = true;
      });
      return;
    }

    // ✅ EMAIL VERIFICATION FLOW — HARD BLOCK
    if (uri.queryParameters.containsKey('code')) {
      // 🔥 DO NOT allow session usage
      await _client.auth.signOut();

      setState(() {
        _session = null;
        _isEmailVerifiedPage = true;
        _ready = true;
      });

      // 🚫 CRITICAL: stop here — do NOT continue
      return;
    }

    // 🔁 AUTH STATE LISTENER (NORMAL APP FLOW ONLY)
    _client.auth.onAuthStateChange.listen((data) async {
      if (!mounted) return;

      final session = data.session;

      // 🚫 Block unverified users
      if (session != null && session.user.emailConfirmedAt == null) {
        await _client.auth.signOut();
        setState(() {
          _session = null;
          _ready = true;
        });
        return;
      }

      setState(() {
        _session = session;
        _ready = true;
      });
    });

    // 🔁 COLD START SESSION CHECK
    final session = _client.auth.currentSession;

    if (session != null && session.user.emailConfirmedAt == null) {
      await _client.auth.signOut();
      setState(() {
        _session = null;
        _ready = true;
      });
      return;
    }

    setState(() {
      _session = session;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isRecovery) return const ResetPasswordPage();

    if (_isEmailVerifiedPage) return const EmailVerificationPage();

    if (_session != null) return const MainDashboard();

    return const LoginPage();
  }
}
