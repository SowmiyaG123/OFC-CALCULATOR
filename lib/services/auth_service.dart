import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as app_user;

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  /// 🔹 REGISTER (AUTH ONLY — EMAIL CONFIRMATION)
  Future<void> registerUser(String email, String password) async {
    try {
      final res = await _client.auth.signUp(
        email: email.trim(),
        password: password.trim(),
      );

      if (res.user == null) {
        throw Exception('Auth user creation failed');
      }
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<app_user.User?> getCurrentUser() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return null;

    final profile =
        await _client.from('profiles').select().eq('id', authUser.id).single();

    return app_user.User.fromJson(profile);
  }

  /// 🔹 LOGIN
  Future<app_user.User> login(String email, String password) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final authUser = res.user;
      if (authUser == null) {
        throw Exception('Invalid credentials');
      }

      if (authUser.emailConfirmedAt == null) {
        await _client.auth.signOut();
        throw Exception('Please verify your email before logging in.');
      }

      await movePendingProfileToProfiles();

      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', authUser.id)
          .single();

      return app_user.User.fromJson(profile);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> movePendingProfileToProfiles() async {
    final user = _client.auth.currentUser;
    if (user == null || user.email == null) return;

    final existing = await _client
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();

    if (existing != null) return;

    final pending = await _client
        .from('pending_profiles')
        .select()
        .eq('email', user.email!)
        .maybeSingle();

    if (pending == null) return;

    await _client.from('profiles').insert({
      'id': user.id,
      'email': user.email,
      'name': pending['name'],
      'phone': pending['phone'],
      'network_name': pending['network_name'],
      'location': pending['location'],
      'role': 'user',
    });

    await _client.from('pending_profiles').delete().eq('email', user.email!);
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }
}
