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

  /// List all profiles (admin RLS). Returns id, email, role, is_active, created_at and scan count.
  Future<List<AdminProfileRow>> listProfiles() async {
    if (!isAvailable) return [];
    try {
      final res = await _client.from('profiles').select('id, email, role, is_active, created_at').order('created_at', ascending: false);
      final list = (res as List).cast<Map<String, dynamic>>();
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
          createdAt: p['created_at'] != null ? DateTime.parse(p['created_at'] as String) : null,
          scanCount: scanCount,
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
  Future<bool> setActive(String userId, bool active) async {
    if (!isAvailable) return false;
    try {
      await _client.from('profiles').update({'is_active': active, 'updated_at': DateTime.now().toIso8601String()}).eq('id', userId);
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
}

class AdminProfileRow {
  final String id;
  final String email;
  final String role;
  final bool isActive;
  final DateTime? createdAt;
  final int scanCount;

  AdminProfileRow({
    required this.id,
    required this.email,
    required this.role,
    required this.isActive,
    this.createdAt,
    required this.scanCount,
  });
}
