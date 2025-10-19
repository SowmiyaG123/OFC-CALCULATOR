import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart' as local_user;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 🔹 LOGIN using Firebase Auth
  Future<local_user.User?> login(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? firebaseUser = result.user;
      if (firebaseUser != null) {
        return local_user.User(
          email: firebaseUser.email ?? '',
          name: firebaseUser.displayName ?? 'User',
          phone: firebaseUser.phoneNumber ?? '',
        );
      }
    } on FirebaseAuthException catch (e) {
      print('Login error: ${e.message}');
      throw Exception(
          e.message ?? 'Login failed'); // better to throw for UI feedback
    }
    return null;
  }

  /// 🔹 REGISTER new user in Firebase
  Future<void> registerUser(local_user.User user, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: user.email,
        password: password,
      );

      // Update display name for Firebase user
      await result.user?.updateDisplayName(user.name);
      await result.user?.reload();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('User with this email already exists');
      } else {
        throw Exception(e.message ?? 'Registration failed');
      }
    }
  }

  /// 🔹 RESET PASSWORD via Firebase
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      print('Reset password error: ${e.message}');
      throw Exception(e.message ?? 'Failed to send reset email');
    }
  }

  /// 🔹 Get currently logged in user
  Future<local_user.User?> getCurrentUser() async {
    User? firebaseUser = _auth.currentUser;

    if (firebaseUser != null) {
      return local_user.User(
        email: firebaseUser.email ?? '',
        name: firebaseUser.displayName ?? 'User',
        phone: firebaseUser.phoneNumber ?? '',
      );
    }
    return null;
  }

  /// 🔹 Logout current user
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// 🔹 Check login state
  bool get isLoggedIn => _auth.currentUser != null;
}
