import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:herbascan/core/models/cloud_scan.dart';
import 'package:herbascan/core/services/herbarium_service.dart';
import 'package:herbascan/core/services/training_dataset_service.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/features/admin/widgets/trigger_training_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Training Images Upload Sheet
// ─────────────────────────────────────────────────────────────────────────────

class TrainingImagesSheet extends StatefulWidget {
  const TrainingImagesSheet({
    super.key,
    required this.plantName,
    required this.plantSlug,
    required this.onUploaded,
  });

  final String plantName;
  final String plantSlug;

  /// Called with the new total image count after a successful upload.
  final void Function(int totalCount) onUploaded;

  @override
  State<TrainingImagesSheet> createState() => _TrainingImagesSheetState();
}

class _TrainingImagesSheetState extends State<TrainingImagesSheet> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selected = [];
  bool _uploading = false;
  double _progress = 0.0;
  int _uploadedCount = 0;
  bool _done = false;
  int _existingCount = 0;
  List<CloudScan> _approvedScans = [];
  bool _includeApprovedScans = true;
  List<String> _uploadErrors = [];

  @override
  void initState() {
    super.initState();
    _fetchExistingCount();
    _fetchApprovedScans();
  }

  Future<void> _fetchExistingCount() async {
    final count =
        await TrainingDatasetService().getImageCount(widget.plantSlug);
    if (mounted) setState(() => _existingCount = count);
  }

  Future<void> _fetchApprovedScans() async {
    final scans =
        await HerbariumService().getApprovedScans(widget.plantSlug);
    if (mounted) setState(() => _approvedScans = scans);
  }

  int get _eligibleScansCount => _approvedScans.where((s) => s.trainingEligible).length;

  void _showApprovedScansPreview() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manage Approved Scans'),
        content: SizedBox(
          width: double.maxFinite,
          height: 240,
          child: StatefulBuilder(
            builder: (ctx, setStateDialog) {
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _approvedScans.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final scan = _approvedScans[i];
                  final url = scan.imageUrl;
                  final isIncluded = scan.trainingEligible;
                  
                  return SizedBox(
                    width: 160,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: url == null 
                                ? const Icon(Icons.image_not_supported) 
                                : Image.network(url, fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Include', style: TextStyle(fontSize: 12)),
                          value: isIncluded,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (val) async {
                            if (val == null) return;
                            
                            // Optimistically update UI
                            setStateDialog(() {
                              _approvedScans[i] = scan.copyWith(trainingEligible: val);
                            });
                            setState(() {});
                            
                            bool success;
                            if (val) {
                              success = await HerbariumService().approveForTraining(scan.id, widget.plantSlug);
                            } else {
                              success = await HerbariumService().unapproveForTraining(scan.id, widget.plantSlug);
                            }
                            
                            if (!success) {
                              // Revert on failure
                              setStateDialog(() {
                                _approvedScans[i] = scan.copyWith(trainingEligible: !val);
                              });
                              setState(() {});
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Failed to update status.')),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _pick() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) {
      setState(() {
        _selected = picked;
        _done = false;
        _progress = 0.0;
        _uploadedCount = 0;
        _uploadErrors = [];
      });
    }
  }

  Future<void> _upload() async {
    if (_selected.isEmpty || _uploading) return;
    setState(() {
      _uploading = true;
      _progress = 0.0;
      _uploadedCount = 0;
      _uploadErrors = [];
    });

    final result = await TrainingDatasetService().uploadImages(
      widget.plantSlug,
      _selected,
      onProgress: (p, u, _) {
        if (mounted)
          setState(() {
            _progress = p;
            _uploadedCount = u;
          });
      },
    );

    if (mounted) {
      final newTotal = _existingCount + result.uploaded;
      setState(() {
        _uploading = false;
        _uploadedCount = result.uploaded;
        _done = result.uploaded > 0;
        _existingCount = newTotal;
        _uploadErrors = result.errors;
      });
      if (result.uploaded > 0) widget.onUploaded(newTotal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const purple = Color(0xFF6366F1);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_photo_alternate_rounded,
                      color: purple, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Training Images',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      Text(
                        widget.plantName,
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.55)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Current count chip
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: purple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$_existingCount images already uploaded',
                  style: const TextStyle(
                      fontSize: 11, color: purple, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── From Approved Scans ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.botanicalPrimary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.botanicalPrimary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.model_training_rounded,
                              size: 16, color: AppTheme.botanicalPrimary),
                          const SizedBox(width: 6),
                          const Text(
                            'From Approved Scans',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.botanicalPrimary),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              AppTheme.botanicalPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '$_eligibleScansCount approved scan image${_eligibleScansCount == 1 ? '' : 's'} included',
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.botanicalPrimary,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (_approvedScans.isNotEmpty)
                        TextButton(
                          onPressed: _showApprovedScansPreview,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Preview', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Include in next training run',
                          style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.75)),
                        ),
                      ),
                      Switch(
                        value: _includeApprovedScans,
                        activeThumbColor: AppTheme.botanicalPrimary,
                        onChanged: (v) =>
                            setState(() => _includeApprovedScans = v),
                      ),
                    ],
                  ),
                  if (!_includeApprovedScans)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Approved scan copies already in training-datasets will still be picked up by the training pipeline.',
                        style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Pick button
            if (_selected.isEmpty)
              OutlinedButton.icon(
                onPressed: _uploading ? null : _pick,
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Select Images'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _uploading ? null : _pick,
                      icon: const Icon(Icons.photo_library_rounded),
                      label: Text('Change Selection (${_selected.length})'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _uploading
                        ? null
                        : () => setState(() {
                              _selected.clear();
                              _done = false;
                            }),
                    icon: const Icon(Icons.clear_all_rounded, color: Colors.red),
                    label: const Text('Clear', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),

            // Preview grid
            if (_selected.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selected.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => FutureBuilder<Uint8List>(
                    future: _selected[i].readAsBytes(),
                    builder: (_, snap) {
                      if (snap.hasData) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                snap.data!,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: -4,
                              right: -4,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() => _selected.removeAt(i));
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                      return Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.image_outlined),
                      );
                    },
                  ),
                ),
              ),
            ],

            // Upload button
            if (_selected.isNotEmpty && !_done) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _uploading ? null : _upload,
                icon: _uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(_uploading
                    ? 'Uploading $_uploadedCount / ${_selected.length}…'
                    : 'Upload ${_selected.length} Images'),
                style: FilledButton.styleFrom(
                  backgroundColor: purple,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],

            // Progress bar
            if (_uploading) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: purple.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(purple),
                borderRadius: BorderRadius.circular(4),
              ),
            ],

            // Success
            if (_done) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.botanicalPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.botanicalPrimary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppTheme.botanicalPrimary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$_uploadedCount images uploaded. Total: $_existingCount.',
                        style: const TextStyle(
                            color: AppTheme.botanicalPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Upload errors — shown even on partial success
            if (_uploadErrors.isNotEmpty && !_uploading) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.errorColor.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppTheme.errorColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '${_uploadErrors.length} upload(s) failed',
                          style: const TextStyle(
                              color: AppTheme.errorColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Show the first error in full — it usually contains the root cause
                    Text(
                      _uploadErrors.first,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.errorColor),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Common causes:\n'
                      '• The "training-datasets" bucket does not exist in Supabase Storage\n'
                      '• RLS policy does not allow authenticated uploads\n'
                      '• File is too large (Supabase free tier: 50 MB per file)',
                      style: TextStyle(fontSize: 11, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),
            TriggerTrainingWidget(
              plantSlug: widget.plantSlug,
              newClassName: widget.plantName,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
