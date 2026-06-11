import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:herbascan/core/services/toxic_plant_catalog_service.dart';
import 'package:herbascan/core/services/toxic_plant_image_service.dart';
import 'package:herbascan/core/theme/app_theme.dart';

/// Admin module for managing the toxic plants catalog and display photos.
///
/// Loads plant entries from `toxic_plants_catalog` (Supabase) and display photos
/// from `toxic_plant_images`. Admins can add, edit, delete catalog entries and
/// upload/replace/remove photos per plant.
class AdminToxicPlantsScreen extends StatefulWidget {
  const AdminToxicPlantsScreen({super.key});

  @override
  State<AdminToxicPlantsScreen> createState() => _AdminToxicPlantsScreenState();
}

class _AdminToxicPlantsScreenState extends State<AdminToxicPlantsScreen> {
  final ToxicPlantCatalogService _catalogService = ToxicPlantCatalogService();
  final ToxicPlantImageService _imageService = ToxicPlantImageService();
  final ImagePicker _picker = ImagePicker();

  // Plant catalog entries loaded from Supabase
  List<Map<String, dynamic>> _plants = [];
  // slug → image entry
  Map<String, ToxicPlantImageEntry> _imageEntries = {};
  // slug → uploading flag
  final Map<String, bool> _uploading = {};

  bool _loading = true;
  String? _error;

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
      final plants = await _catalogService.fetchAllAdmin();
      final images = await _imageService.listAll();
      final imageMap = {for (final e in images) e.slug: e};
      if (mounted) {
        setState(() {
          _plants = plants;
          _imageEntries = imageMap;
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

  // ── Photo management ────────────────────────────────────────────────────────

  Future<void> _pickAndUpload(String slug, String commonName) async {
    final xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (xfile == null || !mounted) return;

    setState(() => _uploading[slug] = true);

    try {
      final url = await _imageService.uploadAndSave(slug, commonName, xfile);

      if (!mounted) return;
      setState(() {
        _uploading[slug] = false;
        _imageEntries[slug] = (_imageEntries[slug] ??
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
    final ok = await _imageService.removeImage(slug);
    if (!mounted) return;
    setState(() {
      _uploading[slug] = false;
      if (ok) {
        final existing = _imageEntries[slug];
        if (existing != null) {
          _imageEntries[slug] = ToxicPlantImageEntry(
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

  // ── Catalog CRUD ────────────────────────────────────────────────────────────

  Future<void> _showEditDialog({Map<String, dynamic>? existing}) async {
    final isAdd = existing == null;
    final formKey = GlobalKey<FormState>();
    final slugCtrl = TextEditingController(text: existing?['slug'] ?? '');
    final commonNameCtrl =
        TextEditingController(text: existing?['common_name'] ?? '');
    final scientificNameCtrl =
        TextEditingController(text: existing?['scientific_name'] ?? '');
    final localNameCtrl = TextEditingController(text: existing?['local_name'] ?? '');
    final harmCtrl = TextEditingController(text: existing?['harm'] ?? '');
    final toxinCtrl = TextEditingController(text: existing?['toxin'] ?? '');
    final symptomsCtrl = TextEditingController(text: existing?['symptoms'] ?? '');
    final appearanceCtrl =
        TextEditingController(text: existing?['appearance'] ?? '');
    final habitatCtrl = TextEditingController(text: existing?['habitat'] ?? '');
    final orderCtrl = TextEditingController(
        text: (existing?['display_order'] ?? 0).toString());
    bool isActive = existing?['is_active'] as bool? ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAdd ? 'Add Toxic Plant' : 'Edit Plant Entry'),
        scrollable: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField('Slug *', slugCtrl, enabled: isAdd,
                    hint: 'url-safe-id'),
                _dialogField('Common Name *', commonNameCtrl),
                _dialogField('Scientific Name *', scientificNameCtrl),
                _dialogField('Local Name', localNameCtrl),
                _dialogField('Harm *', harmCtrl,
                    hint: 'e.g. Heavy toxins, Mild toxins'),
                _dialogField('Toxin *', toxinCtrl,
                    hint: 'e.g. Calcium oxalate crystals'),
                _dialogField('Symptoms *', symptomsCtrl, maxLines: 3),
                _dialogField('Appearance *', appearanceCtrl, maxLines: 3),
                _dialogField('Habitat *', habitatCtrl, maxLines: 3),
                _dialogField('Display Order', orderCtrl,
                    hint: 'Number, lower = first'),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active on Browse Screen'),
                  value: isActive,
                  onChanged: (v) => isActive = v,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final data = <String, dynamic>{
                if (isAdd) 'slug': slugCtrl.text.trim(),
                'common_name': commonNameCtrl.text.trim(),
                'scientific_name': scientificNameCtrl.text.trim(),
                'local_name': localNameCtrl.text.trim(),
                'harm': harmCtrl.text.trim(),
                'toxin': toxinCtrl.text.trim(),
                'symptoms': symptomsCtrl.text.trim(),
                'appearance': appearanceCtrl.text.trim(),
                'habitat': habitatCtrl.text.trim(),
                'display_order': int.tryParse(orderCtrl.text.trim()) ?? 0,
                'is_active': isActive,
              };
              bool ok;
              if (isAdd) {
                ok = await _catalogService.insert(data);
              } else {
                ok = await _catalogService.update(existing!['slug'], data);
              }
              if (ctx.mounted) Navigator.pop(ctx, ok);
            },
            child: Text(isAdd ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) _load();
  }

  Future<void> _confirmDelete(Map<String, dynamic> plant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete plant entry?'),
        content: Text(
            'Permanently delete "${plant['common_name']}" from the catalog? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await _catalogService.delete(plant['slug']);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Plant deleted.' : 'Failed to delete plant.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (ok) _load();
  }

  Future<void> _toggleActive(Map<String, dynamic> plant) async {
    final newActive = !(plant['is_active'] as bool? ?? true);
    await _catalogService.update(plant['slug'], {'is_active': newActive});
    if (mounted) _load();
  }

  Widget _dialogField(String label, TextEditingController controller,
      {bool enabled = true, String? hint, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        validator: (v) =>
            label.contains('*') && (v == null || v.trim().isEmpty)
                ? '$label is required'
                : null,
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

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
                  'Toxic Plants Catalog',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${_plants.length} entries — add, edit, or remove catalog entries and manage display photos.',
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
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: () => _showEditDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Plant'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.botanicalPrimary,
            ),
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
        final slug = plant['slug'] as String? ?? '';
        final entry = _imageEntries[slug];
        final isUploading = _uploading[slug] == true;
        return _buildPlantCard(theme, plant, entry, isUploading);
      },
    );
  }

  Widget _buildPlantCard(
    ThemeData theme,
    Map<String, dynamic> plant,
    ToxicPlantImageEntry? imageEntry,
    bool isUploading,
  ) {
    final slug = plant['slug'] as String? ?? '';
    final commonName = plant['common_name'] as String? ?? '';
    final scientificName = plant['scientific_name'] as String? ?? '';
    final isActive = plant['is_active'] as bool? ?? true;

    final imageUrl = imageEntry?.imageUrl;
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              commonName,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppTheme.botanicalPrimary
                                      .withValues(alpha: 0.12)
                                  : Colors.grey.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              isActive ? 'Active' : 'Hidden',
                              style: TextStyle(
                                color: isActive
                                    ? AppTheme.botanicalPrimary
                                    : Colors.grey,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        scientificName,
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
            // ── Bottom row: action buttons ───────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                      isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18),
                  tooltip: isActive ? 'Hide from browse' : 'Show on browse',
                  onPressed: () => _toggleActive(plant),
                ),
                const SizedBox(width: 4),
                FilledButton.icon(
                  onPressed: isUploading
                      ? null
                      : () => _pickAndUpload(slug, commonName),
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
                        : () => _confirmRemove(slug, commonName),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Remove'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Edit entry',
                  onPressed: () => _showEditDialog(existing: plant),
                ),
                IconButton(
                  icon: Icon(Icons.delete_forever_outlined,
                      size: 18, color: theme.colorScheme.error),
                  tooltip: 'Delete entry',
                  onPressed: () => _confirmDelete(plant),
                ),
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
