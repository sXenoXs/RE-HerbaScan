import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:herbascan/core/config/supabase_config.dart';
import 'package:herbascan/core/models/cloud_scan.dart';
import 'package:herbascan/core/models/scan_result.dart';
import 'package:path_provider/path_provider.dart';

const String _bucket = 'herbarium-images';

/// Personal Herbarium: upload scan images and metadata to Supabase, fetch/delete cloud scans.
class HerbariumService {
  static HerbariumService? _instance;
  factory HerbariumService() => _instance ??= HerbariumService._internal();
  HerbariumService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  bool get isAvailable => isSupabaseConfigured && _client.auth.currentUser != null;

  /// Upload image to Storage and insert scan row. Returns scan id or null on failure.
  /// Also uploads the heatmap (gradCAM) image if present, storing its URL in metadata.
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

    // Upload heatmap image if it exists locally, store its public URL in metadata
    final updatedMetadata = Map<String, dynamic>.from(result.metadata);
    final gradCAMPath = result.gradCAMPath;
    if (gradCAMPath != null && gradCAMPath.isNotEmpty) {
      try {
        final gradcamFile = File(gradCAMPath);
        if (await gradcamFile.exists()) {
          final gradcamStoragePath = '$userId/${scanId}_gradcam.jpg';
          await _client.storage.from(_bucket).upload(
                gradcamStoragePath,
                gradcamFile,
                fileOptions: const FileOptions(upsert: true),
              );
          final gradcamUrl = _client.storage
              .from(_bucket)
              .getPublicUrl(gradcamStoragePath);
          updatedMetadata['gradcam_url'] = gradcamUrl;
          if (kDebugMode) debugPrint('[HerbariumService] uploadScan: heatmap uploaded ok');
        }
      } catch (e) {
        // Heatmap upload is best-effort — don't fail the whole upload
        if (kDebugMode) debugPrint('[HerbariumService] uploadScan: heatmap upload skipped: $e');
      }
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
        'metadata': updatedMetadata,
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

  /// Delete a scan row (and storage objects). Returns true on success.
  Future<bool> deleteScan(String scanId) async {
    if (!isAvailable) return false;
    final userId = _client.auth.currentUser!.id;
    try {
      await _client.storage.from(_bucket).remove([
        '$userId/$scanId.jpg',
        '$userId/${scanId}_gradcam.jpg',
      ]);
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
        await _client.storage.from(_bucket).remove([
          '${scan.userId}/${scan.id}.jpg',
          '${scan.userId}/${scan.id}_gradcam.jpg',
        ]);
      } catch (_) {}
    }
    try {
      await _client.from('scans').delete().eq('id', scan.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Download a cloud scan image to local storage and build a ScanResult for device history.
  /// Also downloads the heatmap image if a gradcam_url is stored in metadata.
  /// Returns the ScanResult on success, null on failure. Caller should call PlantProvider.addScanResult(result).
  Future<ScanResult?> downloadToDevice(CloudScan scan) async {
    if (scan.imageUrl == null || scan.imageUrl!.isEmpty) {
      if (kDebugMode) debugPrint('[HerbariumService] downloadToDevice: no imageUrl');
      return null;
    }
    try {
      final response = await http.get(Uri.parse(scan.imageUrl!));
      if (response.statusCode != 200) {
        if (kDebugMode) debugPrint('[HerbariumService] downloadToDevice: HTTP ${response.statusCode}');
        return null;
      }
      final dir = await getApplicationDocumentsDirectory();
      final localDir = dir.path;
      final filePath = '$localDir/${scan.id}.jpg';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      // Download heatmap image if a URL was stored during upload
      String? gradCAMPath;
      final metadata = scan.metadata ?? {};
      final gradcamUrl = metadata['gradcam_url'] as String?;
      if (gradcamUrl != null && gradcamUrl.isNotEmpty) {
        try {
          final gradcamResponse = await http.get(Uri.parse(gradcamUrl));
          if (gradcamResponse.statusCode == 200) {
            final gradcamFilePath = '$localDir/${scan.id}_gradcam.jpg';
            await File(gradcamFilePath).writeAsBytes(gradcamResponse.bodyBytes);
            gradCAMPath = gradcamFilePath;
            if (kDebugMode) debugPrint('[HerbariumService] downloadToDevice: heatmap saved $gradcamFilePath');
          } else {
            if (kDebugMode) debugPrint('[HerbariumService] downloadToDevice: heatmap HTTP ${gradcamResponse.statusCode}');
          }
        } catch (e) {
          // Heatmap download is best-effort — don't fail the whole download
          if (kDebugMode) debugPrint('[HerbariumService] downloadToDevice: heatmap download skipped: $e');
        }
      }

      final predictions = <Prediction>[];
      final rawPreds = scan.predictions ?? metadata['predictions'] as List<dynamic>?;
      if (rawPreds != null) {
        for (final p in rawPreds) {
          if (p is Map<String, dynamic>) {
            predictions.add(Prediction.fromJson(p));
          } else if (p is Map) {
            predictions.add(Prediction.fromJson(Map<String, dynamic>.from(p)));
          }
        }
      }
      if (predictions.isEmpty && scan.plantId != null) {
        predictions.add(Prediction(
          plantId: scan.plantId!,
          plantName: scan.plantId!,
          scientificName: '',
          confidence: scan.confidenceScore ?? 0,
          features: {},
        ));
      }

      final result = ScanResult(
        id: scan.id,
        plant: null,
        confidenceScore: scan.confidenceScore ?? 0,
        predictions: predictions,
        imagePath: filePath,
        scanDate: scan.scanDate,
        gradCAMPath: gradCAMPath,
        metadata: metadata,
        isOfflineScan: false,
      );
      if (kDebugMode) debugPrint('[HerbariumService] downloadToDevice: saved $filePath');
      return result;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[HerbariumService] downloadToDevice: $e');
        debugPrint('[HerbariumService] downloadToDevice stack: $st');
      }
      return null;
    }
  }
}
