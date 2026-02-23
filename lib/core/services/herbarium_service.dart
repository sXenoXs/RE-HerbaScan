import 'dart:io';
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
    if (!isAvailable) return null;
    final userId = _client.auth.currentUser!.id;
    final scanId = result.id;

    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;
      final path = '$userId/$scanId.jpg';
      await _client.storage.from(_bucket).upload(
            path,
            file,
            fileOptions: const FileOptions(upsert: true),
          );
      final imageUrl = _client.storage.from(_bucket).getPublicUrl(path);

      await _client.from('scans').insert({
        'id': scanId,
        'user_id': userId,
        'plant_id': result.plant?.id,
        'scan_date': result.scanDate.toIso8601String(),
        'image_url': imageUrl,
        'confidence_score': result.confidenceScore,
        'predictions': result.predictions.map((p) => p.toJson()).toList(),
        'metadata': result.metadata,
        'status': 'pending',
      });
      return scanId;
    } catch (_) {
      return null;
    }
  }

  /// Fetch current user's cloud scans, newest first.
  Future<List<CloudScan>> getMyScans() async {
    if (!isAvailable) return [];
    try {
      final res = await _client
          .from('scans')
          .select()
          .eq('user_id', _client.auth.currentUser!.id)
          .order('scan_date', ascending: false);
      return (res as List).map((e) => CloudScan.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
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

  /// Admin: fetch all scans (RLS allows when role is admin). Returns empty if not admin.
  Future<List<CloudScan>> getAdminScans() async {
    if (!isAvailable) return [];
    try {
      final res = await _client.from('scans').select().order('scan_date', ascending: false);
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
