import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:herbascan/core/config/supabase_config.dart';
import 'package:herbascan/core/services/auth_service.dart';
const String _bucket = 'herbarium-images';

/// Admin-only: list profiles, deactivate user, delete user (storage + auth).
/// Query only public.profiles; do not expose auth.users.
class AdminUserService {
  static AdminUserService? _instance;
  factory AdminUserService() => _instance ??= AdminUserService._internal();
  AdminUserService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  bool get isAvailable => isSupabaseConfigured && _client.auth.currentUser != null;

  /// List all profiles (admin RLS). Returns id, email, role, is_active, created_at,
  /// suspension_reason, force_verified_notice, role_change_notice, and scan count.
  Future<List<AdminProfileRow>> listProfiles() async {
    if (!isAvailable) return [];
    try {
      List<Map<String, dynamic>> list;
      try {
        final rpcRes = await _client.rpc('get_admin_users');
        list = (rpcRes as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AdminUserService] RPC get_admin_users failed: $e');
        }
        final res = await _client
            .from('profiles')
            .select(
                'id, email, role, is_active, created_at, suspension_reason, force_verified_notice, role_change_notice')
            .order('created_at', ascending: false);
        list = (res as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      final rows = <AdminProfileRow>[];
      for (final p in list) {
        final id = p['id'] as String?;
        if (id == null) continue;
        final scanCount = await _getScanCount(id);
        rows.add(AdminProfileRow(
          id: id,
          email: p['email'] as String? ?? '',
          role: p['role'] as String? ?? 'user',
          isActive: p['is_active'] as bool? ?? true,
          createdAt: p['created_at'] != null
              ? DateTime.parse(p['created_at'] as String)
              : null,
          scanCount: scanCount,
          suspensionReason: p['suspension_reason'] as String?,
          forceVerifiedNotice: p['force_verified_notice'] as bool? ?? false,
          roleChangeNotice: p['role_change_notice'] as bool? ?? false,
          emailConfirmedAt: p['email_confirmed_at'] != null
              ? DateTime.tryParse(p['email_confirmed_at'] as String)
              : null,
        ));
      }
      return rows;
    } catch (_) {
      return [];
    }
  }

  Future<int> _getScanCount(String userId) async {
    try {
      final res = await _client.from('scans').select('id').eq('user_id', userId);
      return (res as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// Set is_active for a user (admin only). When false, app should treat as deactivated.
  /// [reason] is stored in suspension_reason; pass null when reactivating.
  Future<bool> setActive(String userId, bool active, {String? reason}) async {
    if (!isAvailable) return false;
    try {
      final update = <String, dynamic>{
        'is_active': active,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (!active) {
        // Store the suspension reason (may be null = no reason given)
        update['suspension_reason'] = reason;
      } else {
        // Clear reason when reactivating
        update['suspension_reason'] = null;
      }
      await _client.from('profiles').update(update).eq('id', userId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Set role for a user (admin only). Typically 'admin' or 'user'.
  /// Also sets role_change_notice = true so the user sees a one-time dialog on next login.
  Future<bool> setRole(String userId, String role) async {
    if (!isAvailable) return false;
    try {
      await _client.from('profiles').update({
        'role': role,
        'role_change_notice': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Delete user: remove their storage objects then call delete-user Edge Function. Admin only.
  Future<void> deleteUser(String userId) async {
    if (!isAvailable) throw Exception('Not available');
    try {
      final files = await _client.storage.from(_bucket).list(path: userId);
      if (files.isNotEmpty) {
        final names = files.map((f) => '$userId/${f.name}').toList();
        await _client.storage.from(_bucket).remove(names);
      }
    } catch (_) {
      // Continue; storage may be empty or already removed
    }
    await AuthService().adminDeleteUser(userId);
  }

  /// Force-verify a user's email (admin only). Calls force-verify-user Edge Function.
  /// Returns true on success. Throws on failure (e.g. function not deployed, not admin).
  Future<bool> forceVerifyUser(String userId) async {
    if (!isAvailable) return false;
    try {
      await AuthService().adminForceVerifyUser(userId);
      return true;
    } catch (_) {
      rethrow;
    }
  }

  /// Dismiss the force_verified_notice for the currently signed-in user.
  Future<void> clearForceVerifiedNotice(String userId) async {
    if (!isAvailable) return;
    try {
      await _client
          .from('profiles')
          .update({'force_verified_notice': false})
          .eq('id', userId);
    } catch (_) {}
  }

  /// Dismiss the role_change_notice for the currently signed-in user.
  Future<void> clearRoleChangeNotice(String userId) async {
    if (!isAvailable) return;
    try {
      await _client
          .from('profiles')
          .update({'role_change_notice': false})
          .eq('id', userId);
    } catch (_) {}
  }

  /// Fetch a single user's profile notices + is_active + suspension_reason.
  /// Used by the login flow to check for pending notices/suspension.
  Future<Map<String, dynamic>?> getProfileNotices(String userId) async {
    if (!isAvailable) return null;
    try {
      final res = await _client
          .from('profiles')
          .select(
              'is_active, suspension_reason, force_verified_notice, role_change_notice, role')
          .eq('id', userId)
          .maybeSingle();
      return res as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }
}

class AdminProfileRow {
  final String id;
  final String email;
  final String role;
  final bool isActive;
  final DateTime? createdAt;
  final int scanCount;
  final String? suspensionReason;
  final bool forceVerifiedNotice;
  final bool roleChangeNotice;
  final DateTime? emailConfirmedAt;

  AdminProfileRow({
    required this.id,
    required this.email,
    required this.role,
    required this.isActive,
    this.createdAt,
    required this.scanCount,
    this.suspensionReason,
    this.forceVerifiedNotice = false,
    this.roleChangeNotice = false,
    this.emailConfirmedAt,
  });
}
