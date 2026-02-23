import 'package:supabase_flutter/supabase_flutter.dart';

/// Wraps Supabase Auth for HerbaScan. Handles sign in, sign up, sign out,
/// session, and JWT access token. No custom auth logic.
class AuthService {
  static AuthService? _instance;
  factory AuthService() => _instance ??= AuthService._internal();
  AuthService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  /// Current session (null if signed out).
  Session? get currentSession => _client.auth.currentSession;

  /// Current user (null if signed out).
  User? get currentUser => _client.auth.currentUser;

  /// JWT access token for Railway backend. Null if not signed in.
  String? get accessToken => currentSession?.accessToken;

  /// Whether a user is signed in.
  bool get isSignedIn => currentUser != null;

  /// Auth state changes stream (for reactive UI).
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Sign in with email and password.
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Sign up with email and password.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return _client.auth.signUp(email: email, password: password);
  }

  /// Sign out.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Reset password (sends email via Supabase).
  Future<void> resetPasswordForEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }
}
