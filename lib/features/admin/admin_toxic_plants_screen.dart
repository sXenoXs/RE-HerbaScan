import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:herbascan/core/services/toxic_plant_image_service.dart';
import 'package:herbascan/core/theme/app_theme.dart';

/// Admin module for managing display photos of the informational toxic plants
/// shown on the Browse screen's "Toxic Plants" tab.
///
/// Each plant card shows the current photo (if any) and an upload button.
/// After a successful upload the image is reflected immediately on the user-facing
/// Browse screen on the next load (or app restart).
class AdminToxicPlantsScreen extends StatefulWidget {
  const AdminToxicPlantsScreen({super.key});

  @override
  State<AdminToxicPlantsScreen> createState() => _AdminToxicPlantsScreenState();
}

class _AdminToxicPlantsScreenState extends State<AdminToxicPlantsScreen> {
  final ToxicPlantImageService _service = ToxicPlantImageService();
  final ImagePicker _picker = ImagePicker();

  // slug → entry (loaded from Supabase)
  Map<String, ToxicPlantImageEntry> _entries = {};
  // slug → uploading flag
  final Map<String, bool> _uploading = {};

  bool _loading = true;
  String? _error;

  // Canonical static list — matches browse_screen.dart _toxicPlants order.
  static const _plants = [
    (slug: 'dumb-cane', commonName: 'Dumb Cane', scientificName: 'Dieffenbachia picta'),
    (slug: 'physic-nut-tuba-tuba', commonName: 'Physic Nut / Tuba-tuba', scientificName: 'Jatropha curcas'),
    (slug: 'snake-plant', commonName: 'Snake Plant', scientificName: 'Dracaena trifasciata'),
    (slug: 'cycads', commonName: 'Cycads', scientificName: 'Cycadophyta'),
    (slug: 'daphne', commonName: 'Daphne', scientificName: 'Daphne laureola'),
    (slug: 'angels-trumpet', commonName: "Angel's Trumpet", scientificName: 'Brugmansia spp.'),
    (slug: 'lantana', commonName: 'Lantana', scientificName: 'Lantana camara'),
    (slug: 'calla-lily', commonName: 'Calla Lily', scientificName: 'Zantedeschia spp.'),
    (slug: 'poinsettia', commonName: 'Poinsettia', scientificName: 'Euphorbia pulcherrima'),
    (slug: 'cacti-and-succulents', commonName: 'Cacti and Succulents', scientificName: 'Various'),
    (slug: 'rhus-wax-tree', commonName: 'Rhus / Wax Tree', scientificName: 'Toxicodendron spp.'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.listAll();
      final map = {for (final e in list) e.slug: e};
      if (mounted) {
        setState(() {
          _entries = map;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickAndUpload(String slug, String commonName) async {
    final xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (xfile == null || !mounted) return;

    setState(() => _uploading[slug] = true);

    try {
      final url = await _service.uploadAndSave(slug, commonName, xfile);

      if (!mounted) return;
      setState(() {
        _uploading[slug] = false;
        _entries[slug] = (_entries[slug] ??
                ToxicPlantImageEntry(slug: slug, commonName: commonName))
            .copyWith(imageUrl: url);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Photo uploaded successfully.'),
          backgroundColor: AppTheme.botanicalPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading[slug] = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  Future<void> _confirmRemove(String slug, String commonName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove photo?'),
        content: Text(
            'The display photo for "$commonName" will be removed. Users will see the default warning icon instead.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _uploading[slug] = true);
    final ok = await _service.removeImage(slug);
    if (!mounted) return;
    setState(() {
      _uploading[slug] = false;
      if (ok) {
        final existing = _entries[slug];
        if (existing != null) {
          _entries[slug] = ToxicPlantImageEntry(
            slug: existing.slug,
            commonName: existing.commonName,
            imageUrl: null,
            updatedAt: DateTime.now(),
          );
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Photo removed.' : 'Failed to remove photo.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(theme),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildError(theme)
                  : _buildList(theme),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.warning_amber_rounded,
                color: Colors.red.shade700, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Toxic Plants',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Manage display photos for the 11 informational toxic plants.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text('Failed to load', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(_error ?? '',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildList(ThemeData theme) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _plants.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final plant = _plants[index];
        final entry = _entries[plant.slug];
        final isUploading = _uploading[plant.slug] == true;
        return _buildPlantCard(theme, plant, entry, isUploading);
      },
    );
  }

  // _buildPlantCard()
  // Refactored from a single horizontal Row to a two-row Column so the button
  // column no longer competes with the plant-name text for horizontal space.
  Widget _buildPlantCard(
    ThemeData theme,
    ({String slug, String commonName, String scientificName}) plant,
    ToxicPlantImageEntry? entry,
    bool isUploading,
  ) {
    final imageUrl = entry?.imageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final color = Colors.red.shade700;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top row: thumbnail + plant info ──────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image preview / placeholder
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: isUploading
                        ? Container(
                            color: Colors.red.shade50,
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.red,
                              ),
                            ),
                          )
                        : hasImage
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: Colors.red.shade50,
                                  child: const Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.red)),
                                ),
                                errorWidget: (_, __, ___) =>
                                    _placeholderBox(color),
                              )
                            : _placeholderBox(color),
                  ),
                ),
                const SizedBox(width: 16),
                // Plant info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plant.commonName,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        plant.scientificName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            hasImage
                                ? Icons.check_circle_rounded
                                : Icons.image_not_supported_outlined,
                            size: 14,
                            color: hasImage
                                ? AppTheme.botanicalPrimary
                                : AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasImage ? 'Photo uploaded' : 'No photo yet',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: hasImage
                                  ? AppTheme.botanicalPrimary
                                  : AppTheme.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Bottom row: action buttons, right-aligned ─────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.icon(
                  onPressed: isUploading
                      ? null
                      : () => _pickAndUpload(plant.slug, plant.commonName),
                  icon: Icon(
                    hasImage ? Icons.edit_rounded : Icons.upload_rounded,
                    size: 16,
                  ),
                  label: Text(hasImage ? 'Replace' : 'Upload'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppTheme.botanicalPrimary,
                    minimumSize: const Size(100, 36),
                  ),
                ),
                if (hasImage) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: isUploading
                        ? null
                        : () => _confirmRemove(plant.slug, plant.commonName),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Remove'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderBox(Color color) {
    return Container(
      color: color.withValues(alpha: 0.08),
      child: Center(
        child: Icon(
          Icons.warning_amber_rounded,
          size: 36,
          color: color.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
