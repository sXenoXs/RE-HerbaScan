import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:herbascan/core/config/supabase_config.dart';

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
  /// Uses [authRedirectUrl] so the link opens the app; add it to Supabase Redirect URLs.
  /// For 6-digit OTP flow, edit the Reset password template to show {{ .Token }} and use [verifyOtpRecovery].
  Future<void> resetPasswordForEmail(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: authRedirectUrl,
    );
  }

  /// Verify the 6-digit (or token) code from the password reset email and establish a recovery session.
  /// After this, the user can call [updatePassword] to set a new password.
  /// [email] must be the address the reset email was sent to (required by Supabase).
  Future<void> verifyOtpRecovery({required String email, required String token}) async {
    await _client.auth.verifyOTP(
      type: OtpType.recovery,
      email: email.trim(),
      token: token.trim(),
    );
  }

  /// Verify the 6-digit (or token) code from the signup confirmation email.
  /// After this, the user is confirmed and Supabase may establish a session; the app should refresh auth state.
  Future<void> verifyOtpSignup({required String email, required String token}) async {
    await _client.auth.verifyOTP(
      type: OtpType.signup,
      email: email.trim(),
      token: token.trim(),
    );
  }

  /// Update current user's password. User must be signed in.
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Update current user's email. User must be signed in. May send confirmation to new email.
  Future<void> updateEmail(String newEmail) async {
    await _client.auth.updateUser(UserAttributes(email: newEmail));
  }

  /// Request deletion of the current user's account.
  /// Calls the Supabase Edge Function "delete-user" which uses the service role to delete the user.
  /// Requires the delete-user Edge Function to be deployed (see supabase/README.md).
  /// After successful deletion the client session is invalid; the app should sign out.
  Future<void> deleteAccount() async {
    await _client.auth.refreshSession();
    if (currentSession == null) {
      throw Exception('Not signed in');
    }
    if (kDebugMode) {
      debugPrint('[AuthService][deleteAccount] session present, using SDK auth');
    }
    try {
      // Let the Supabase client attach the session JWT automatically (do not pass Authorization header).
      final res = await _client.functions.invoke('delete-user');
      if (kDebugMode) {
        debugPrint('[AuthService][deleteAccount] response status: ${res.status}, data: ${res.data}');
      }
      if (res.status == 404) {
        throw Exception(
          'Delete account is not available: the delete-user function is not deployed. '
          'Deploy it with: npx supabase functions deploy delete-user (see supabase/README.md).',
        );
      }
      if (res.status != 200) {
        final msg = res.data != null
            ? (res.data is Map ? (res.data as Map)['message'] ?? res.data.toString() : res.data.toString())
            : 'Failed to delete account (${res.status})';
        throw Exception(msg.toString());
      }
    } on FunctionException catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthService][deleteAccount] FunctionException status: ${e.status}, details: ${e.details}');
      }
      if (e.status == 404) {
        throw Exception(
          'Delete account is not available: the delete-user function is not deployed. '
          'Deploy it with: npx supabase functions deploy delete-user (see supabase/README.md).',
        );
      }
      rethrow;
    }
  }

  /// Admin: delete another user. Caller must be admin. Invokes delete-user with body { user_id }.
  /// Client must delete the user's storage objects before calling this (see AdminUserService.deleteUser).
  Future<void> adminDeleteUser(String targetUserId) async {
    await _client.auth.refreshSession();
    if (currentSession == null) {
      throw Exception('Not signed in');
    }
    if (kDebugMode) {
      debugPrint('[AuthService][adminDeleteUser] targetUserId: $targetUserId, using SDK auth');
    }
    try {
      // Let the Supabase client attach the session JWT automatically (do not pass Authorization header).
      final res = await _client.functions.invoke(
        'delete-user',
        body: {'user_id': targetUserId},
      );
      if (kDebugMode) {
        debugPrint('[AuthService][adminDeleteUser] response status: ${res.status}, data: ${res.data}');
      }
      if (res.status != 200) {
        final msg = res.data != null
            ? (res.data is Map ? (res.data as Map)['message'] ?? res.data.toString() : res.data.toString())
            : 'Failed to delete user (${res.status})';
        throw Exception(msg.toString());
      }
    } on FunctionException catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthService][adminDeleteUser] FunctionException status: ${e.status}, details: ${e.details}');
      }
      rethrow;
    }
  }
}
