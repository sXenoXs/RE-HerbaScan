import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:herbascan/core/services/auth_service.dart';

void _debugAuth(String message) {
  if (kDebugMode) debugPrint('[AuthProvider] $message');
}

/// Role for RBAC. Default for new signups is [user]; admin set manually in DB.
enum AppRole { user, admin }

/// Holds auth state: session, user, role. Listens to Supabase auth state changes.
class AuthProvider extends ChangeNotifier {
  final AuthService _auth = AuthService();

  User? _user;
  AppRole _role = AppRole.user;
  bool _initialized = false;
  bool _deactivatedByAdmin = false;

  User? get user => _user;
  AppRole get role => _role;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _role == AppRole.admin;
  bool get initialized => _initialized;

  /// True after sign-out due to admin deactivation (is_active: false).
  bool get wasDeactivatedByAdmin => _deactivatedByAdmin;

  void clearDeactivatedFlag() {
    _deactivatedByAdmin = false;
    notifyListeners();
  }

  /// JWT access token for Railway /identify and Supabase API calls.
  String? get accessToken => _auth.accessToken;

  AuthProvider() {
    _user = _auth.currentUser;
    _debugAuth('constructor: _user=${_user?.id} email=${_user?.email}');
    _loadRole().then((_) {
      _debugAuth('constructor _loadRole done: isAdmin=$isAdmin role=$_role');
      notifyListeners();
    });
    _auth.authStateChanges.listen((data) async {
      _user = data.session?.user;
      _debugAuth('authStateChanges: _user=${_user?.id} email=${_user?.email}');
      await _loadRole();
      _debugAuth('authStateChanges after _loadRole: isAdmin=$isAdmin');
      notifyListeners();
    });
    _initialized = true;
    notifyListeners();
  }

  /// Load role from profiles table. Defaults to [AppRole.user] if no profile. Syncs email to profile for display in admin.
  Future<void> _loadRole() async {
    _user ??= _auth.currentUser;
    _debugAuth('_loadRole: _user=${_user?.id} (after sync from currentUser)');
    if (_user == null) {
      _role = AppRole.user;
      _debugAuth('_loadRole: no user, set role=user');
      return;
    }
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('role, is_active')
          .eq('id', _user!.id)
          .maybeSingle();
      _debugAuth('_loadRole: profiles result=$res');
      final isActive = res?['is_active'] as bool? ?? true;
      if (!isActive) {
        _debugAuth('_loadRole: user inactive (deactivated by admin), signing out');
        _deactivatedByAdmin = true;
        await _auth.signOut();
        _user = null;
        _role = AppRole.user;
        return;
      }
      final roleStr = res?['role'] as String?;
      _role = roleStr == 'admin' ? AppRole.admin : AppRole.user;
      _debugAuth(
          '_loadRole: roleStr=$roleStr => _role=$_role isAdmin=$isAdmin');
      final email = _user!.email;
      if (email != null && email.isNotEmpty) {
        try {
          await Supabase.instance.client.from('profiles').update({
            'email': email,
            'updated_at': DateTime.now().toIso8601String()
          }).eq('id', _user!.id);
        } catch (_) {}
      }
    } catch (e, st) {
      _debugAuth('_loadRole: error=$e');
      if (kDebugMode) debugPrint('[AuthProvider] _loadRole stack: $st');
      _role = AppRole.user;
    }
  }

  /// Sign in with email and password.
  Future<void> signIn({required String email, required String password}) async {
    _debugAuth('signIn: starting for $email');
    await _auth.signInWithPassword(email: email, password: password);
    _user = _auth.currentUser;
    _debugAuth('signIn: after signInWithPassword _user=${_user?.id}');
    await _loadRole();
    _debugAuth(
        'signIn: after _loadRole isAdmin=$isAdmin, calling notifyListeners');
    notifyListeners();
  }

  /// Sign up with email and password.
  /// Throws an [AuthException] with a user-friendly message if the email is
  /// already registered (Supabase returns an empty identities list silently).
  Future<void> signUp({required String email, required String password}) async {
    _debugAuth('signUp: starting for $email');
    final response = await _auth.signUp(email: email, password: password);
    // Supabase silently "succeeds" for duplicate emails but returns an empty
    // identities list — detect this and surface it as an error.
    if (response.user != null &&
        (response.user!.identities == null ||
            response.user!.identities!.isEmpty)) {
      throw const AuthException(
        'This email is already registered. Try signing in instead.',
      );
    }
    _user = _auth.currentUser;
    _debugAuth('signUp: after signUp _user=${_user?.id}');
    await _loadRole();
    _debugAuth(
        'signUp: after _loadRole isAdmin=$isAdmin, calling notifyListeners');
    notifyListeners();
  }

  /// Sign out.
  Future<void> signOut() async {
    await _auth.signOut();
    _user = null;
    _role = AppRole.user;
    notifyListeners();
  }

  /// Refresh role (e.g. after admin grants role in dashboard).
  Future<void> refreshRole() async {
    _debugAuth('refreshRole: calling _loadRole');
    await _loadRole();
    _debugAuth('refreshRole: isAdmin=$isAdmin, calling notifyListeners');
    notifyListeners();
  }

  /// Send password reset email. Does not require sign-in.
  Future<void> requestPasswordReset(String email) async {
    await _auth.resetPasswordForEmail(email);
  }

  /// Verify the 6-digit OTP from the password reset email; establishes recovery session.
  /// Call [updatePassword] after this to set the new password.
  /// [email] must be the address the reset email was sent to.
  Future<void> verifyRecoveryOtp(
      {required String email, required String token}) async {
    _debugAuth('verifyRecoveryOtp: starting');
    await _auth.verifyOtpRecovery(email: email, token: token);
    _user = _auth.currentUser;
    _debugAuth('verifyRecoveryOtp: _user=${_user?.id}');
    await _loadRole();
    _debugAuth('verifyRecoveryOtp: isAdmin=$isAdmin');
    notifyListeners();
  }

  /// Verify the 6-digit OTP from the signup confirmation email. Confirms the user; may establish a session.
  Future<void> verifySignupOtp(
      {required String email, required String token}) async {
    _debugAuth('verifySignupOtp: starting');
    await _auth.verifyOtpSignup(email: email, token: token);
    _user = _auth.currentUser;
    _debugAuth('verifySignupOtp: _user=${_user?.id}');
    await _loadRole();
    _debugAuth('verifySignupOtp: isAdmin=$isAdmin');
    notifyListeners();
  }

  /// Update current user's password. Requires sign-in.
  Future<void> updatePassword(String newPassword) async {
    await _auth.updatePassword(newPassword);
    notifyListeners();
  }

  /// Update current user's email. Requires sign-in.
  Future<void> updateEmail(String newEmail) async {
    await _auth.updateEmail(newEmail);
    _user = _auth.currentUser;
    notifyListeners();
  }

  /// Delete the current user's account (Supabase Auth + profile). Calls the delete-user Edge Function.
  /// Signs out after successful deletion. Throws on failure.
  Future<void> deleteAccount() async {
    await _auth.deleteAccount();
    await signOut();
  }
}
