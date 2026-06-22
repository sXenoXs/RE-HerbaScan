import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:herbascan/core/models/plant.dart';
import 'package:herbascan/core/models/safety_profile.dart';
import 'package:herbascan/core/services/catalog_plant_admin_service.dart';
import 'package:herbascan/core/services/training_dataset_service.dart';
import 'package:herbascan/core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Internal data holders for medicinal-use entries in Step 3
// ─────────────────────────────────────────────────────────────────────────────

class _MedicinalEntry {
  final TextEditingController conditionCtrl;
  final TextEditingController descriptionCtrl;
  _MedicinalEntry()
      : conditionCtrl = TextEditingController(),
        descriptionCtrl = TextEditingController();
  void dispose() {
    conditionCtrl.dispose();
    descriptionCtrl.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wizard
// ─────────────────────────────────────────────────────────────────────────────

/// 3-step wizard for creating a new plant entry as a Draft.
///
/// Step 1 — Metadata  : Common Name, Scientific Name, plant_slug (with
///                      uniqueness check), Local Name, DOH Approved flag.
/// Step 2 — Images    : Multi-image picker + bulk upload to
///                      training-datasets/{slug}/  with live progress bar.
/// Step 3 — Knowledge : Taxonomy, Ecology, Medicinal Uses, and Safety sections.
///
/// On completion the plant is saved to Supabase as status = 'draft'.
/// Returns `true` to the caller when a plant was successfully created.
class AdminNewPlantWizard extends StatefulWidget {
  const AdminNewPlantWizard({super.key});

  @override
  State<AdminNewPlantWizard> createState() => _AdminNewPlantWizardState();
}

class _AdminNewPlantWizardState extends State<AdminNewPlantWizard> {
  final PageController _pageCtrl = PageController();
  int _currentStep = 0;
  bool _isSaving = false;

  // ── Step 1 ─────────────────────────────────────────────────────────────────
  final _commonNameCtrl = TextEditingController();
  final _scientificNameCtrl = TextEditingController();
  final _localNameCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  bool _isDOHApproved = false;
  bool _checkingSlug = false;
  bool? _slugIsUnique; // null=unchecked, true=unique, false=taken
  String _lastAutoSlug = '';

  // ── Step 2 ─────────────────────────────────────────────────────────────────
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];
  bool _uploading = false;
  double _uploadProgress = 0.0;
  int _uploadedCount = 0;
  bool _imagesUploaded = false;

  // ── Step 3 ─────────────────────────────────────────────────────────────────
  final _familyCtrl = TextEditingController();
  final _genusCtrl = TextEditingController();
  final _speciesCtrl = TextEditingController();
  final _morphologyCtrl = TextEditingController();
  final _ecologyCtrl = TextEditingController();
  final _habitatCtrl = TextEditingController();
  final _climateNotesCtrl = TextEditingController();
  final List<_MedicinalEntry> _medicinalEntries = [];
  bool _isGenerallySafe = true;
  bool _pregnancyWarning = false;
  bool _needsStrictContraindications = false;

  @override
  void initState() {
    super.initState();
    _commonNameCtrl.addListener(_onCommonNameChanged);
    // Start with one blank medicinal entry
    _medicinalEntries.add(_MedicinalEntry());
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _commonNameCtrl.removeListener(_onCommonNameChanged);
    _commonNameCtrl.dispose();
    _scientificNameCtrl.dispose();
    _localNameCtrl.dispose();
    _slugCtrl.dispose();
    _familyCtrl.dispose();
    _genusCtrl.dispose();
    _speciesCtrl.dispose();
    _morphologyCtrl.dispose();
    _ecologyCtrl.dispose();
    _habitatCtrl.dispose();
    _climateNotesCtrl.dispose();
    for (final e in _medicinalEntries) {
      e.dispose();
    }
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _onCommonNameChanged() {
    final raw = _commonNameCtrl.text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s\-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
    // Only auto-fill slug if it hasn't been manually edited
    if (_slugCtrl.text.isEmpty || _slugCtrl.text == _lastAutoSlug) {
      _slugCtrl.text = raw;
      _slugCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _slugCtrl.text.length));
      _lastAutoSlug = raw;
    }
    if (_slugIsUnique != null) setState(() => _slugIsUnique = null);
  }

  Future<void> _checkSlug() async {
    final slug = _slugCtrl.text.trim();
    if (slug.isEmpty) return;
    setState(() {
      _checkingSlug = true;
      _slugIsUnique = null;
    });
    final unique = await CatalogPlantAdminService().checkSlugUnique(slug);
    if (mounted) {
      setState(() {
        _checkingSlug = false;
        _slugIsUnique = unique;
      });
    }
  }

  bool get _step1Valid =>
      _commonNameCtrl.text.trim().isNotEmpty &&
      _scientificNameCtrl.text.trim().isNotEmpty &&
      _slugCtrl.text.trim().isNotEmpty &&
      _slugIsUnique == true;

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) {
      setState(() {
        _selectedImages = picked;
        _imagesUploaded = false;
        _uploadProgress = 0.0;
        _uploadedCount = 0;
      });
    }
  }

  Future<void> _uploadImages() async {
    if (_selectedImages.isEmpty || _uploading) return;
    final slug = _slugCtrl.text.trim();
    if (slug.isEmpty) {
      _showSnack('Set the plant slug in Step 1 first.');
      return;
    }
    setState(() {
      _uploading = true;
      _uploadProgress = 0.0;
      _uploadedCount = 0;
    });
    final result = await TrainingDatasetService().uploadImages(
      slug,
      _selectedImages,
      onProgress: (progress, uploaded, total) {
        if (mounted) {
          setState(() {
            _uploadProgress = progress;
            _uploadedCount = uploaded;
          });
        }
      },
    );
    if (mounted) {
      setState(() {
        _uploading = false;
        _uploadedCount = result.uploaded;
        _imagesUploaded = result.uploaded > 0;
      });
      if (result.hasErrors) {
        _showSnack(
          'Uploaded ${result.uploaded}/${_selectedImages.length}. '
          'Error: ${result.errors.first}',
        );
      } else {
        _showSnack(
            'Uploaded ${result.uploaded} of ${_selectedImages.length} images.');
      }
    }
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageCtrl.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  void _next() {
    if (_currentStep == 0) {
      if (!_step1Valid) {
        _showSnack('Fill all required fields and verify slug uniqueness.');
        return;
      }
    }
    if (_currentStep < 2) _goToStep(_currentStep + 1);
  }

  void _back() {
    if (_currentStep > 0) _goToStep(_currentStep - 1);
  }

  Future<void> _finish() async {
    setState(() => _isSaving = true);

    final slug = _slugCtrl.text.trim();
    final plantId = slug;

    final plant = Plant(
      id: plantId,
      commonName: _commonNameCtrl.text.trim(),
      scientificName: _scientificNameCtrl.text.trim(),
      localName: _localNameCtrl.text.trim(),
      englishName: '',
      family: _familyCtrl.text.trim(),
      genus: _genusCtrl.text.trim(),
      species: _speciesCtrl.text.trim(),
      isDOHApproved: _isDOHApproved,
      morphology: _morphologyCtrl.text.trim(),
      ecology: _ecologyCtrl.text.trim(),
      habitat: _habitatCtrl.text.trim(),
      medicinalUses: _medicinalEntries
          .map((e) => MedicinalUse(
                condition: e.conditionCtrl.text.trim(),
                description: e.descriptionCtrl.text.trim(),
                effectiveness: '',
                activeCompounds: [],
                dosage: '',
                duration: '',
              ))
          .where((u) => u.condition.isNotEmpty)
          .toList(),
      preparationMethods: [],
      safetyWarnings: [],
      imagePath: '',
      imageUrl: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final service = CatalogPlantAdminService();
    final ok = await service.saveCatalogPlant(
      plant,
      climateNotes: _climateNotesCtrl.text.trim(),
      plantSlug: slug,
      status: 'draft',
      trainingImageCount: _uploadedCount,
    );

    if (ok) {
      final safety = SafetyProfile(
        plantId: plantId,
        name: plant.commonName,
        isGenerallySafe: _isGenerallySafe,
        pregnancyWarning: _pregnancyWarning,
        knownSideEffects: const [],
        drugInteractions: const [],
        strictContraindications: const [],
        needsStrictContraindications: _needsStrictContraindications,
      );
      await service.saveCatalogSafety(plantId, safety);
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        _showSnack(
            '${plant.commonName} saved as Draft. Edit further from Plant Catalog.');
        Navigator.pop(context, true);
      } else {
        _showSnack('Save failed. Check your connection and try again.');
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'New Plant',
          style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface),
        ),
      ),
      body: Column(
        children: [
          _StepIndicator(currentStep: _currentStep),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(theme),
                _buildStep2(theme),
                _buildStep3(theme),
              ],
            ),
          ),
          _buildBottomBar(theme),
        ],
      ),
    );
  }

  // ── Step 1: Metadata ───────────────────────────────────────────────────────

  Widget _buildStep1(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WizardStepTitle(
              title: 'Plant Metadata',
              subtitle:
                  'Enter the core identity fields. The slug is used as the training-dataset folder name and must be unique.'),
          const SizedBox(height: 20),

          // Common Name
          _FieldLabel(label: 'Common Name *'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _commonNameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'e.g. Lagundi',
            ),
          ),
          const SizedBox(height: 16),

          // Scientific Name
          _FieldLabel(label: 'Scientific Name *'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _scientificNameCtrl,
            decoration: const InputDecoration(
              hintText: 'e.g. Vitex negundo',
            ),
          ),
          const SizedBox(height: 16),

          // Local Name
          _FieldLabel(label: 'Local Name (optional)'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _localNameCtrl,
            decoration: const InputDecoration(
              hintText: 'e.g. Lagundi (Filipino)',
            ),
          ),
          const SizedBox(height: 16),

          // Slug
          _FieldLabel(label: 'Plant Slug *'),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _slugCtrl,
                  onChanged: (_) =>
                      setState(() => _slugIsUnique = null),
                  decoration: InputDecoration(
                    hintText: 'e.g. lagundi',
                    helperText:
                        'Auto-generated from common name. Must be lowercase, hyphens only.',
                    suffixIcon: _checkingSlug
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)),
                          )
                        : _slugIsUnique == true
                            ? const Icon(Icons.check_circle_rounded,
                                color: AppTheme.botanicalPrimary)
                            : _slugIsUnique == false
                                ? const Icon(Icons.cancel_rounded,
                                    color: AppTheme.errorColor)
                                : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: OutlinedButton(
                  onPressed: _checkingSlug ? null : _checkSlug,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Check'),
                ),
              ),
            ],
          ),
          if (_slugIsUnique == false)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'This slug is already taken. Try a different one.',
                style: TextStyle(
                    color: AppTheme.errorColor, fontSize: 12),
              ),
            ),
          const SizedBox(height: 16),

          // DOH Approved
          _SwitchRow(
            label: 'DOH Approved',
            subtitle:
                'Mark as Department of Health approved medicinal plant',
            value: _isDOHApproved,
            onChanged: (v) => setState(() => _isDOHApproved = v),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Training Images ────────────────────────────────────────────────

  Widget _buildStep2(ThemeData theme) {
    final slug = _slugCtrl.text.trim();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WizardStepTitle(
            title: 'Training Images',
            subtitle:
                'Upload reference photos for this plant. Images are stored at training-datasets/$slug/ in Supabase Storage.',
          ),
          const SizedBox(height: 20),

          // Pick images button
          OutlinedButton.icon(
            onPressed: _uploading ? null : _pickImages,
            icon: const Icon(Icons.add_photo_alternate_rounded),
            label: Text(_selectedImages.isEmpty
                ? 'Pick Images'
                : 'Change Selection (${_selectedImages.length} selected)'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),

          // Image grid preview
          if (_selectedImages.isNotEmpty) ...[
            _ImagePreviewGrid(
              images: _selectedImages,
              onRemove: (index) {
                setState(() {
                  _selectedImages.removeAt(index);
                });
              },
            ),
            const SizedBox(height: 16),
          ],

          // Upload button
          if (_selectedImages.isNotEmpty && !_imagesUploaded) ...[
            FilledButton.icon(
              onPressed: _uploading ? null : _uploadImages,
              icon: const Icon(Icons.cloud_upload_rounded),
              label: Text(_uploading
                  ? 'Uploading…'
                  : 'Upload ${_selectedImages.length} Images'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.botanicalPrimary,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Progress bar
          if (_uploading) ...[
            LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor:
                  AppTheme.botanicalPrimary.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.botanicalPrimary),
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 6),
            Text(
              'Uploaded $_uploadedCount of ${_selectedImages.length}…',
              style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 12),
          ],

          // Success state
          if (_imagesUploaded) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    AppTheme.botanicalPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color:
                        AppTheme.botanicalPrimary.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppTheme.botanicalPrimary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '$_uploadedCount images uploaded successfully.',
                    style: const TextStyle(
                        color: AppTheme.botanicalPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Skip hint
          Text(
            'You can skip this step and add training images later from Plant Catalog.',
            style: TextStyle(
                fontSize: 12,
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Knowledge Entry ────────────────────────────────────────────────

  Widget _buildStep3(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WizardStepTitle(
            title: 'Plant Knowledge',
            subtitle:
                'Fill in the key knowledge sections. You can update these later from Plant Catalog using the full editor.',
          ),
          const SizedBox(height: 20),

          // ── Taxonomy ───────────────────────────────────────────────
          _SectionExpansion(
            icon: Icons.account_tree_rounded,
            color: const Color(0xFF0EA5E9),
            title: 'Taxonomy',
            initiallyExpanded: true,
            children: [
              _FieldRow(
                label: 'Family',
                controller: _familyCtrl,
                hint: 'e.g. Lamiaceae',
              ),
              _FieldRow(
                label: 'Genus',
                controller: _genusCtrl,
                hint: 'e.g. Vitex',
              ),
              _FieldRow(
                label: 'Species',
                controller: _speciesCtrl,
                hint: 'e.g. negundo',
              ),
              _FieldRow(
                label: 'Morphology',
                controller: _morphologyCtrl,
                hint: 'Describe physical characteristics…',
                maxLines: 3,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Ecology ────────────────────────────────────────────────
          _SectionExpansion(
            icon: Icons.forest_rounded,
            color: AppTheme.botanicalPrimary,
            title: 'Ecology',
            children: [
              _FieldRow(
                label: 'Ecology',
                controller: _ecologyCtrl,
                hint: 'Climate, soil, growth conditions…',
                maxLines: 3,
              ),
              _FieldRow(
                label: 'Habitat',
                controller: _habitatCtrl,
                hint: 'Where it grows naturally…',
                maxLines: 2,
              ),
              _FieldRow(
                label: 'Climate Notes',
                controller: _climateNotesCtrl,
                hint: 'Temperature range, rainfall…',
                maxLines: 2,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Medicinal Preparation ──────────────────────────────────
          _SectionExpansion(
            icon: Icons.medical_services_rounded,
            color: const Color(0xFF8B5CF6),
            title: 'Medicinal Preparation',
            children: [
              ...List.generate(_medicinalEntries.length, (i) {
                return _MedicinalEntryWidget(
                  index: i,
                  entry: _medicinalEntries[i],
                  onRemove: _medicinalEntries.length > 1
                      ? () => setState(() {
                            _medicinalEntries[i].dispose();
                            _medicinalEntries.removeAt(i);
                          })
                      : null,
                );
              }),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _medicinalEntries.add(_MedicinalEntry())),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Another Condition'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Safety ─────────────────────────────────────────────────
          _SectionExpansion(
            icon: Icons.health_and_safety_rounded,
            color: AppTheme.warningAmber,
            title: 'Safety',
            children: [
              _SwitchRow(
                label: 'Generally Safe',
                subtitle: 'Safe for general adult use as directed',
                value: _isGenerallySafe,
                onChanged: (v) =>
                    setState(() => _isGenerallySafe = v),
              ),
              _SwitchRow(
                label: 'Pregnancy Warning',
                subtitle: 'Not recommended during pregnancy',
                value: _pregnancyWarning,
                onChanged: (v) =>
                    setState(() => _pregnancyWarning = v),
              ),
              _SwitchRow(
                label: 'Strict Contraindications',
                subtitle:
                    'Requires prominent "use with strict caution" warning',
                value: _needsStrictContraindications,
                onChanged: (v) =>
                    setState(() => _needsStrictContraindications = v),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Detailed side effects, drug interactions and contraindication lists can be added from the full editor in Plant Catalog.',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Bottom action bar ──────────────────────────────────────────────────────

  Widget _buildBottomBar(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          // Back
          if (_currentStep > 0)
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _back,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),

          const Spacer(),

          // Next / Finish
          if (_currentStep < 2)
            FilledButton.icon(
              onPressed: _isSaving ? null : _next,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Next'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.botanicalPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            )
          else
            FilledButton.icon(
              onPressed: _isSaving ? null : _finish,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 18),
              label: const Text('Save as Draft'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.botanicalPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets used inside the wizard
// ─────────────────────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});
  final int currentStep;

  static const _labels = ['Metadata', 'Images', 'Knowledge'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
            bottom: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: List.generate(3, (i) {
          final isActive = i == currentStep;
          final isDone = i < currentStep;
          return Expanded(
            child: Row(
              children: [
                // Circle
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? AppTheme.botanicalPrimary
                        : isActive
                            ? AppTheme.botanicalPrimary
                                .withValues(alpha: 0.25)
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.10),
                    border: isActive
                        ? Border.all(
                            color: AppTheme.botanicalPrimary, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check_rounded,
                            size: 15, color: Colors.white)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isActive
                                  ? AppTheme.botanicalPrimaryL
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.35),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _labels[i],
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: isActive || isDone
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: isActive
                        ? (isDark
                            ? AppTheme.botanicalPrimaryL
                            : AppTheme.botanicalPrimary)
                        : isDone
                            ? theme.colorScheme.onSurface
                                .withValues(alpha: 0.7)
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.35),
                  ),
                ),
                if (i < 2)
                  Expanded(
                    child: Divider(
                      color: theme.dividerColor.withValues(alpha: 0.4),
                      thickness: 1,
                      indent: 8,
                      endIndent: 0,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _WizardStepTitle extends StatelessWidget {
  const _WizardStepTitle(
      {required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: TextStyle(
              fontSize: 13,
              color:
                  theme.colorScheme.onSurface.withValues(alpha: 0.55),
            )),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: label),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 14)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.55))),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.botanicalPrimary,
          ),
        ],
      ),
    );
  }
}

class _SectionExpansion extends StatelessWidget {
  const _SectionExpansion({
    required this.icon,
    required this.color,
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: color.withValues(alpha: 0.18), width: 1.2),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          children: children,
        ),
      ),
    );
  }
}

class _MedicinalEntryWidget extends StatelessWidget {
  const _MedicinalEntryWidget({
    required this.index,
    required this.entry,
    this.onRemove,
  });

  final int index;
  final _MedicinalEntry entry;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Condition ${index + 1}',
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppTheme.textSecondary)),
              const Spacer(),
              if (onRemove != null)
                IconButton(
                  icon: Icon(Icons.remove_circle_outline_rounded,
                      size: 18,
                      color: theme.colorScheme.error
                          .withValues(alpha: 0.7)),
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: entry.conditionCtrl,
            decoration: const InputDecoration(
              hintText: 'e.g. Cough & Asthma',
              labelText: 'Condition',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: entry.descriptionCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'How is this plant used for this condition?',
              labelText: 'Description',
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePreviewGrid extends StatelessWidget {
  const _ImagePreviewGrid({required this.images, this.onRemove});
  final List<XFile> images;
  final void Function(int index)? onRemove;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: images.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemBuilder: (ctx, i) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: kIsWeb
                  ? Image.network(
                      images[i].path,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppTheme.darkCard,
                        child: const Icon(Icons.image_rounded,
                            size: 24, color: Colors.white38),
                      ),
                    )
                  : Image.file(
                      File(images[i].path),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppTheme.darkCard,
                        child: const Icon(Icons.image_rounded,
                            size: 24, color: Colors.white38),
                      ),
                    ),
            ),
            if (onRemove != null)
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () => onRemove!(i),
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.close_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
