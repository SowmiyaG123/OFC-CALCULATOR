import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as local_user;

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  /// 🔹 LOGIN using Supabase Auth
  Future<local_user.User?> login(String email, String password) async {
    try {
      final AuthResponse res = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final User? supabaseUser = res.user;
      if (supabaseUser == null) {
        throw Exception("Invalid credentials");
      }

      return local_user.User(
        email: supabaseUser.email ?? '',
        name: supabaseUser.userMetadata?['name']?.toString() ?? 'User',
        phone: supabaseUser.userMetadata?['phone']?.toString() ?? '',
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  /// 🔹 REGISTER new user using Supabase Auth
  Future<void> registerUser(
    local_user.User user,
    String password,
  ) async {
    try {
      final AuthResponse res = await _client.auth.signUp(
        email: user.email.trim(),
        password: password.trim(),
        data: {
          'name': user.name.trim(),
          'phone': user.phone.trim(),
        },
      );

      if (res.user == null) {
        throw Exception('Registration failed — please check details');
      }
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  /// 🔹 RESET PASSWORD via Supabase
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  /// 🔹 Get currently logged in user
  local_user.User? getCurrentUser() {
    final User? supabaseUser = _client.auth.currentUser;

    if (supabaseUser == null) return null;

    return local_user.User(
      email: supabaseUser.email ?? '',
      name: supabaseUser.userMetadata?['name']?.toString() ?? 'User',
      phone: supabaseUser.userMetadata?['phone']?.toString() ?? '',
    );
  }

  /// 🔹 Logout user
  Future<void> logout() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }

  /// 🔹 Check if user logged in
  bool get isLoggedIn => _client.auth.currentUser != null;
}
