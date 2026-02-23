import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:herbascan/core/services/auth_service.dart';

/// Role for RBAC. Default for new signups is [user]; admin set manually in DB.
enum AppRole { user, admin }

/// Holds auth state: session, user, role. Listens to Supabase auth state changes.
class AuthProvider extends ChangeNotifier {
  final AuthService _auth = AuthService();

  User? _user;
  AppRole _role = AppRole.user;
  bool _initialized = false;

  User? get user => _user;
  AppRole get role => _role;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _role == AppRole.admin;
  bool get initialized => _initialized;

  /// JWT access token for Railway /identify and Supabase API calls.
  String? get accessToken => _auth.accessToken;

  AuthProvider() {
    _user = _auth.currentUser;
    _loadRole();
    _auth.authStateChanges.listen((data) {
      _user = data.session?.user;
      _loadRole();
      notifyListeners();
    });
    _initialized = true;
    notifyListeners();
  }

  /// Load role from profiles table. Defaults to [AppRole.user] if no profile.
  Future<void> _loadRole() async {
    if (_user == null) {
      _role = AppRole.user;
      return;
    }
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', _user!.id)
          .maybeSingle();
      final roleStr = res?['role'] as String?;
      _role = roleStr == 'admin' ? AppRole.admin : AppRole.user;
    } catch (_) {
      _role = AppRole.user;
    }
  }

  /// Sign in with email and password.
  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithPassword(email: email, password: password);
    await _loadRole();
    notifyListeners();
  }

  /// Sign up with email and password.
  Future<void> signUp({required String email, required String password}) async {
    await _auth.signUp(email: email, password: password);
    await _loadRole();
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
    await _loadRole();
    notifyListeners();
  }
}
