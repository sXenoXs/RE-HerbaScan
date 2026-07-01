import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:herbascan/core/config/supabase_config.dart';
import 'package:herbascan/core/models/data_deletion_request.dart';

/// Service for requesting and managing data deletion via the
/// `data_deletion_requests` Supabase table.
///
/// Users submit a deletion request with an optional reason.
/// Admins review, approve, or reject.
class DataDeletionService {
  static DataDeletionService? _instance;
  factory DataDeletionService() => _instance ??= DataDeletionService._internal();
  DataDeletionService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  bool get _canRead => isSupabaseConfigured;

  /// User: submit a data deletion request.
  /// Returns true on success.
  Future<bool> submitRequest({String reason = ''}) async {
    if (!_canRead) return false;
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      await _client.from('data_deletion_requests').insert({
        'user_id': userId,
        'reason': reason.isEmpty ? null : reason,
        'status': 'pending',
      });
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[DataDeletionService] submitRequest: $e');
      return false;
    }
  }

  /// User: check if the current user already has a pending request.
  /// Returns the status or null if no request exists.
  Future<String?> getMyRequestStatus() async {
    if (!_canRead) return null;
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final rows = await _client
          .from('data_deletion_requests')
          .select('status')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1) as List<dynamic>;

      if (rows.isNotEmpty && rows.first['status'] != null) {
        return rows.first['status'] as String;
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[DataDeletionService] getMyRequestStatus: $e');
      return null;
    }
  }

  /// User: cancel own pending request.
  Future<bool> cancelMyRequest() async {
    if (!_canRead) return false;
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      await _client
          .from('data_deletion_requests')
          .delete()
          .eq('user_id', userId)
          .eq('status', 'pending');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[DataDeletionService] cancelMyRequest: $e');
      return false;
    }
  }

  /// Admin: fetch all deletion requests with user emails from profiles.
  Future<List<DataDeletionRequest>> fetchAllAdmin({
    String? statusFilter,
  }) async {
    if (!_canRead) return [];
    try {
      var query = _client
          .from('data_deletion_requests')
          .select('id, user_id, profiles!inner(email), reason, status, reviewed_by, reviewed_at, created_at');

      if (statusFilter != null && statusFilter.isNotEmpty) {
        query = query.eq('status', statusFilter);
      }

      final rows = await query.order('created_at', ascending: false) as List<dynamic>;
      return rows.map((r) {
        final map = <String, dynamic>{};
        final d = r as Map<String, dynamic>;
        map['id'] = d['id'];
        map['user_id'] = d['user_id'];
        // Extract email from the joined profiles record
        final profiles = d['profiles'];
        if (profiles is Map<String, dynamic>) {
          map['email'] = profiles['email'];
        }
        map['reason'] = d['reason'];
        map['status'] = d['status'];
        map['reviewed_by'] = d['reviewed_by'];
        map['reviewed_at'] = d['reviewed_at'];
        map['created_at'] = d['created_at'];
        return DataDeletionRequest.fromMap(map);
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[DataDeletionService] fetchAllAdmin: $e');
      return [];
    }
  }

  /// Admin: update a request status (approve or reject).
  Future<bool> updateRequestStatus(int requestId, String status) async {
    if (status == 'approved') return approveRequest(requestId.toString());
    if (status == 'rejected') return rejectRequest(requestId.toString());
    return false;
  }

  /// Admin: permanently delete a deletion request record.
  Future<bool> adminDeleteRequest(int requestId) async {
    if (!_canRead) return false;
    try {
      await _client
          .from('data_deletion_requests')
          .delete()
          .eq('id', requestId);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[DataDeletionService] adminDeleteRequest: $e');
      return false;
    }
  }

  /// Admin: fetch all deletion requests (raw, no email join).
  /// Returns list of maps with id, user_id, reason, status, reviewed_by, reviewed_at, created_at.
  Future<List<Map<String, dynamic>>> fetchAll({String? statusFilter}) async {
    if (!_canRead) return [];
    try {
      var query = _client
          .from('data_deletion_requests')
          .select('id, user_id, reason, status, reviewed_by, reviewed_at, created_at');

      if (statusFilter != null && statusFilter.isNotEmpty) {
        query = query.eq('status', statusFilter);
      }

      final rows = await query.order('created_at', ascending: false) as List<dynamic>;
      return rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[DataDeletionService] fetchAll: $e');
      return [];
    }
  }

  /// Admin: approve a deletion request.
  /// Returns true on success.
  Future<bool> approveRequest(String requestId) async {
    if (!_canRead) return false;
    try {
      final adminId = _client.auth.currentUser?.id;
      await _client.from('data_deletion_requests').update({
        'status': 'approved',
        'reviewed_by': adminId,
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[DataDeletionService] approveRequest: $e');
      return false;
    }
  }

  /// Admin: reject a deletion request.
  /// Returns true on success.
  Future<bool> rejectRequest(String requestId) async {
    if (!_canRead) return false;
    try {
      final adminId = _client.auth.currentUser?.id;
      await _client.from('data_deletion_requests').update({
        'status': 'rejected',
        'reviewed_by': adminId,
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[DataDeletionService] rejectRequest: $e');
      return false;
    }
  }
}
