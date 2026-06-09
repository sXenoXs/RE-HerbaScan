import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:herbascan/core/services/herbarium_service.dart';
import 'package:herbascan/core/services/training_dataset_service.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/features/admin/admin_new_plant_wizard.dart';

/// Admin Dashboard Overview — landing screen of the admin portal.
///
/// Shows live metrics (total plants, pending drafts, training image count)
/// and a Quick Actions section to launch the New Plant Wizard.
class AdminOverviewScreen extends StatefulWidget {
  const AdminOverviewScreen({super.key});

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  int _totalPlants = 0;
  int _pendingDrafts = 0;
  int _totalTrainingImages = 0;
  String _currentModelVersion = '—';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;

      // Total catalog plants
      final totalRes =
          await client.from('catalog_plants').select('id');
      final total = (totalRes as List).length;

      // Draft plants only
      int drafts = 0;
      try {
        final draftRes = await client
            .from('catalog_plants')
            .select('id')
            .eq('status', 'draft');
        drafts = (draftRes as List).length;
      } catch (_) {
        // status column may not exist yet — graceful degradation
      }

      // Training images: manual uploads + approved scan copies (run in parallel)
      final imageCounts = await Future.wait([
        TrainingDatasetService().getTotalImageCount(),
        HerbariumService().getTrainingEligibleScanCount(),
      ]);
      final imageCount = imageCounts[0] + imageCounts[1];

      // Current deployed model version
      String modelVersion = '—';
      try {
        final mv = await client
            .from('model_versions')
            .select('version')
            .eq('is_active', true)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (mv != null) modelVersion = mv['version'] as String? ?? '—';
      } catch (_) {}

      if (mounted) {
        setState(() {
          _totalPlants = total;
          _pendingDrafts = drafts;
          _totalTrainingImages = imageCount;
          _currentModelVersion = modelVersion;
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

  void _openDeployModel() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DeployModelSheet(
        currentVersion: _currentModelVersion,
        onDeployed: _loadMetrics,
      ),
    );
  }

  void _openNewPlantWizard() {
    Navigator.of(context)
        .push<bool>(
          MaterialPageRoute(
            builder: (_) => const AdminNewPlantWizard(),
          ),
        )
        .then((created) {
      if (created == true) _loadMetrics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadMetrics,
        color: AppTheme.botanicalPrimary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── App bar ────────────────────────────────────────────────────
            // SliverAppBar
            SliverAppBar(
              automaticallyImplyLeading: false,
              pinned: true,
              elevation: 0,
              scrolledUnderElevation: 1,
              backgroundColor: theme.scaffoldBackgroundColor,
              title: Text(
                'Overview',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                  fontSize: 18,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.refresh_rounded,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  tooltip: 'Refresh',
                  onPressed: _loadMetrics,
                ),
              ],
            ),

            // ── Body ───────────────────────────────────────────────────────
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_off_rounded,
                            size: 48,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.35)),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadMetrics,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Section: Metrics ────────────────────────────────
                    _SectionHeader(title: 'Metrics'),
                    const SizedBox(height: 12),
                    _MetricsGrid(
                      totalPlants: _totalPlants,
                      pendingDrafts: _pendingDrafts,
                      totalTrainingImages: _totalTrainingImages,
                    ),
                    const SizedBox(height: 28),

                    // ── Section: Quick Actions ──────────────────────────
                    _SectionHeader(title: 'Quick Actions'),
                    const SizedBox(height: 12),
                    _QuickActionsCard(
                      onAddPlant: _openNewPlantWizard,
                      onDeployModel: _openDeployModel,
                    ),
                    const SizedBox(height: 28),

                    // ── Section: Training Pipeline ──────────────────────
                    _SectionHeader(title: 'ML Training Pipeline'),
                    const SizedBox(height: 12),
                    _PipelineCard(
                      currentModelVersion: _currentModelVersion,
                      pendingDrafts: _pendingDrafts,
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: AppTheme.textSecondary,
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({
    required this.totalPlants,
    required this.pendingDrafts,
    required this.totalTrainingImages,
  });

  final int totalPlants;
  final int pendingDrafts;
  final int totalTrainingImages;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricCard(
        label: 'Medicinal Plants',
        value: '$totalPlants',
        icon: Icons.eco_rounded,
        color: AppTheme.botanicalPrimary,
      ),
      _MetricCard(
        label: 'Pending Drafts',
        value: '$pendingDrafts',
        icon: Icons.pending_actions_rounded,
        color: AppTheme.warningAmber,
      ),
      _MetricCard(
        label: 'Training Images',
        value: '$totalTrainingImages',
        icon: Icons.photo_library_rounded,
        color: const Color(0xFF6366F1),
      ),
    ];

    return LayoutBuilder(builder: (ctx, constraints) {
      if (constraints.maxWidth >= 520) {
        return Row(
          children: cards.indexed
              .map((e) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: e.$1 < cards.length - 1 ? 10 : 0),
                      child: e.$2,
                    ),
                  ))
              .toList(),
        );
      }
      return Column(
        children: cards
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: c,
                ))
            .toList(),
      );
    });
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: color.withValues(alpha: 0.18), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.onAddPlant,
    required this.onDeployModel,
  });
  final VoidCallback onAddPlant;
  final VoidCallback onDeployModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add New Plant
          _ActionRow(
            icon: Icons.add_circle_rounded,
            color: AppTheme.botanicalPrimary,
            title: 'Add New Plant',
            subtitle: 'Launch the 3-step wizard to create a draft plant entry',
            onTap: onAddPlant,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pipeline status card
// ─────────────────────────────────────────────────────────────────────────────

class _PipelineCard extends StatelessWidget {
  const _PipelineCard({
    required this.currentModelVersion,
    required this.pendingDrafts,
  });

  final String currentModelVersion;
  final int pendingDrafts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const purple = Color(0xFF6366F1);

    final steps = [
      (
        num: '1',
        label: 'Add a new plant',
        detail: 'Use the wizard to create a draft entry.',
        done: false,
      ),
      (
        num: '2',
        label: 'Add training photos',
        detail: 'Go to the plant catalog, tap the three‑dot menu, and choose “Training Images then click Upload Images (Minimum of 100 images for better training)”.',
        done: false,
      ),
      (
        num: '3',
        label: 'Train the model',
        detail: 'Click "Start Training" and wait for the model to train, the training time will depend on the number of images uploaded',
        done: false,
      ),
      (
        num: '4',
        label: 'Make the plant live',
        detail: 'In the plant catalog, tap the three‑dot menu and select “Publish” to make it available to users.',
        done: false,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current model chip
          Row(
            children: [
              const Icon(Icons.memory_rounded, size: 16, color: purple),
              const SizedBox(width: 6),
              Text(
                'Active model: ',
                style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
              ),
              Text(
                currentModelVersion,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: purple),
              ),
              if (pendingDrafts > 0) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.warningAmber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '$pendingDrafts draft${pendingDrafts > 1 ? 's' : ''} pending',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.warningAmber,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Steps
          ...steps.asMap().entries.map((e) {
            final i = e.key;
            final step = e.value;
            final isLast = i == steps.length - 1;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: step.done
                            ? AppTheme.botanicalPrimary
                            : purple.withValues(alpha: 0.1),
                        border: step.done
                            ? null
                            : Border.all(
                                color: purple.withValues(alpha: 0.3)),
                      ),
                      child: Center(
                        child: step.done
                            ? const Icon(Icons.check_rounded,
                                size: 13, color: Colors.white)
                            : Text(
                                step.num,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: purple.withValues(alpha: 0.7)),
                              ),
                      ),
                    ),
                    if (!isLast)
                      Container(
                          width: 1, height: 24, color: Colors.grey.shade300),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: step.done
                                  ? AppTheme.botanicalPrimary
                                  : theme.colorScheme.onSurface),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          step.detail,
                          style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Deploy Model sheet
// ─────────────────────────────────────────────────────────────────────────────

class _DeployModelSheet extends StatefulWidget {
  const _DeployModelSheet({
    required this.currentVersion,
    required this.onDeployed,
  });
  final String currentVersion;
  final VoidCallback onDeployed;

  @override
  State<_DeployModelSheet> createState() => _DeployModelSheetState();
}

class _DeployModelSheetState extends State<_DeployModelSheet> {
  final _formKey = GlobalKey<FormState>();
  final _versionCtrl = TextEditingController();
  final _tfliteCtrl = TextEditingController();
  final _classIndicesCtrl = TextEditingController();
  bool _deploying = false;
  String? _resultMsg;
  bool _success = false;

  @override
  void dispose() {
    _versionCtrl.dispose();
    _tfliteCtrl.dispose();
    _classIndicesCtrl.dispose();
    super.dispose();
  }

  Future<void> _deploy() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _deploying = true;
      _resultMsg = null;
    });
    try {
      await Supabase.instance.client.from('model_versions').insert({
        'version': _versionCtrl.text.trim(),
        'is_active': true,
        'tflite_url': _tfliteCtrl.text.trim(),
        'class_indices_url': _classIndicesCtrl.text.trim(),
      });
      // Deactivate previous versions
      await Supabase.instance.client
          .from('model_versions')
          .update({'is_active': false})
          .neq('version', _versionCtrl.text.trim());

      if (mounted) {
        setState(() {
          _deploying = false;
          _success = true;
          _resultMsg =
              'Model v${_versionCtrl.text.trim()} deployed. Devices will update on next launch.';
        });
        widget.onDeployed();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _deploying = false;
          _success = false;
          _resultMsg = 'Deploy failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const purple = Color(0xFF6366F1);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
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
                    child: const Icon(Icons.rocket_launch_rounded,
                        color: purple, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Deploy New Model',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(
                          'Current: ${widget.currentVersion}',
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

              // Info banner
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 16, top: 8),
                decoration: BoxDecoration(
                  color: purple.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: purple.withValues(alpha: 0.2)),
                ),
                child: const Text(
                  'Upload your retrained model files to Supabase Storage first, '
                  'then paste the public URLs below. The app will download the '
                  'new model on the next launch.',
                  style: TextStyle(fontSize: 12),
                ),
              ),

              // Version
              TextFormField(
                controller: _versionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Version *',
                  hintText: 'e.g. 2.1.0',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag_rounded),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // TFLite URL
              _UrlField(
                controller: _tfliteCtrl,
                label: 'model_url (.tflite) *',
                hint: 'https://…/mobilenetv2_multi_output.tflite',
              ),
              const SizedBox(height: 12),

              // Class indices URL
              _UrlField(
                controller: _classIndicesCtrl,
                label: 'class_indices_url (.json) *',
                hint: 'https://…/class_indices.json',
              ),
              const SizedBox(height: 20),

              // Result
              if (_resultMsg != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _success
                        ? AppTheme.botanicalPrimary.withValues(alpha: 0.08)
                        : AppTheme.errorColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _success
                          ? AppTheme.botanicalPrimary.withValues(alpha: 0.3)
                          : AppTheme.errorColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _success
                            ? Icons.check_circle_rounded
                            : Icons.error_outline_rounded,
                        color: _success
                            ? AppTheme.botanicalPrimary
                            : AppTheme.errorColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_resultMsg!,
                              style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Deploy button
              FilledButton.icon(
                onPressed: _deploying ? null : _deploy,
                icon: _deploying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.rocket_launch_rounded),
                label:
                    Text(_deploying ? 'Deploying…' : 'Deploy Model'),
                style: FilledButton.styleFrom(
                  backgroundColor: purple,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrlField extends StatelessWidget {
  const _UrlField({
    required this.controller,
    required this.label,
    required this.hint,
  });
  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.url,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.link_rounded),
        suffixIcon: IconButton(
          icon: const Icon(Icons.paste_rounded, size: 18),
          tooltip: 'Paste',
          onPressed: () async {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            if (data?.text != null) {
              controller.text = data!.text!;
            }
          },
        ),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Required';
        if (!v.trim().startsWith('http')) return 'Must be a valid URL';
        return null;
      },
    );
  }
}
