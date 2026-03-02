import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:herbascan/core/config/supabase_config.dart';
import 'package:herbascan/core/models/cloud_scan.dart';
import 'package:herbascan/core/models/scan_result.dart';

const String _bucket = 'herbarium-images';

/// Personal Herbarium: upload scan images and metadata to Supabase, fetch/delete cloud scans.
class HerbariumService {
  static HerbariumService? _instance;
  factory HerbariumService() => _instance ??= HerbariumService._internal();
  HerbariumService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  bool get isAvailable => isSupabaseConfigured && _client.auth.currentUser != null;

  /// Upload image to Storage and insert scan row. Returns scan id or null on failure.
  Future<String?> uploadScan(ScanResult result, String imagePath) async {
    if (!isAvailable) {
      if (kDebugMode) debugPrint('[HerbariumService] uploadScan: not available (Supabase or not signed in)');
      return null;
    }
    final userId = _client.auth.currentUser!.id;
    final scanId = result.id;

    if (kDebugMode) debugPrint('[HerbariumService] uploadScan: scanId=$scanId imagePath=$imagePath');

    final file = File(imagePath);
    if (!await file.exists()) {
      if (kDebugMode) debugPrint('[HerbariumService] uploadScan: file does not exist at $imagePath');
      return null;
    }

    String imageUrl;
    try {
      final path = '$userId/$scanId.jpg';
      await _client.storage.from(_bucket).upload(
            path,
            file,
            fileOptions: const FileOptions(upsert: true),
          );
      imageUrl = _client.storage.from(_bucket).getPublicUrl(path);
      if (kDebugMode) debugPrint('[HerbariumService] uploadScan: storage upload ok, inserting row');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[HerbariumService] uploadScan: storage upload failed: $e');
        debugPrint('[HerbariumService] uploadScan storage stack: $st');
      }
      return null;
    }

    // Prefer catalog id; when plant not resolved (e.g. from history), use top prediction so cloud shows name not "Unknown plant"
    final plantId = result.plant?.id ??
        result.topPrediction?.plantId ??
        result.topPrediction?.plantName ??
        'Unknown plant';

    try {
      final row = {
        'id': scanId,
        'user_id': userId,
        'plant_id': plantId,
        'scan_date': result.scanDate.toIso8601String(),
        'image_url': imageUrl,
        'confidence_score': result.confidenceScore,
        'predictions': result.predictions.map((p) => p.toJson()).toList(),
        'metadata': result.metadata,
        'status': 'pending',
      };
      await _client.from('scans').upsert(row, onConflict: 'id');
      if (kDebugMode) debugPrint('[HerbariumService] uploadScan: success scanId=$scanId');
      return scanId;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[HerbariumService] uploadScan: insert failed: $e');
        debugPrint('[HerbariumService] uploadScan insert stack: $st');
      }
      return null;
    }
  }

  /// Fetch current user's cloud scans, newest first.
  Future<List<CloudScan>> getMyScans() async {
    if (!isAvailable) {
      if (kDebugMode) debugPrint('[HerbariumService] getMyScans: not available (Supabase or auth missing)');
      return [];
    }
    final userId = _client.auth.currentUser!.id;
    try {
      final res = await _client
          .from('scans')
          .select()
          .eq('user_id', userId)
          .order('scan_date', ascending: false);
      final list = (res as List).map((e) => CloudScan.fromJson(e as Map<String, dynamic>)).toList();
      if (kDebugMode) debugPrint('[HerbariumService] getMyScans: user_id=$userId => ${list.length} scan(s)');
      return list;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[HerbariumService] getMyScans: error=$e');
        debugPrint('[HerbariumService] getMyScans stack: $st');
      }
      return [];
    }
  }

  /// Delete a scan row (and optionally storage object). Returns true on success.
  Future<bool> deleteScan(String scanId) async {
    if (!isAvailable) return false;
    final userId = _client.auth.currentUser!.id;
    try {
      await _client.storage.from(_bucket).remove(['$userId/$scanId.jpg']);
    } catch (_) {}
    try {
      await _client.from('scans').delete().eq('id', scanId).eq('user_id', userId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Admin: fetch scans (RLS allows when role is admin). [statusFilter] e.g. 'pending' to show only pending. Returns empty if not admin.
  Future<List<CloudScan>> getAdminScans({String? statusFilter}) async {
    if (!isAvailable) return [];
    try {
      var query = _client.from('scans').select();
      if (statusFilter != null && statusFilter.isNotEmpty) {
        query = query.eq('status', statusFilter);
      }
      final res = await query.order('scan_date', ascending: false);
      return (res as List).map((e) => CloudScan.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Admin: update scan status (pending | approved | rejected).
  Future<bool> updateScanStatus(String scanId, String status) async {
    if (!isAvailable) return false;
    try {
      await _client.from('scans').update({'status': status}).eq('id', scanId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Admin: delete any scan (row + storage). RLS allows when role is admin.
  Future<bool> adminDeleteScan(CloudScan scan) async {
    if (!isAvailable) return false;
    if (scan.userId != null) {
      try {
        await _client.storage.from(_bucket).remove(['${scan.userId}/${scan.id}.jpg']);
      } catch (_) {}
    }
    try {
      await _client.from('scans').delete().eq('id', scan.id);
      return true;
    } catch (_) {
      return false;
    }
  }
}
