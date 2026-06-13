import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:herbascan/core/services/app_config_service.dart';
import 'package:herbascan/core/theme/app_theme.dart';

/// Admin editor for the app_config Supabase table.
///
/// Allows admins to update:
///   - app_version   → displayed in Settings → Support & About
///   - model_version → displayed in Settings → Support & About
///   - help_content  → JSON blob powering the Help & Tutorial screen
///
/// Changes take effect immediately in the app on next launch (or after
/// AppProvider.loadRemoteConfig() is called).
class AdminAppConfigScreen extends StatefulWidget {
  const AdminAppConfigScreen({super.key});

  @override
  State<AdminAppConfigScreen> createState() => _AdminAppConfigScreenState();
}

class _AdminAppConfigScreenState extends State<AdminAppConfigScreen> {
  final AppConfigService _service = AppConfigService();

  final _appVersionController = TextEditingController();
  final _modelVersionController = TextEditingController();

  final List<Map<String, TextEditingController>> _tipsControllers = [];
  final List<Map<String, TextEditingController>> _issuesControllers = [];
  final List<Map<String, TextEditingController>> _featuresControllers = [];
  final TextEditingController _oodExplanationController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _appVersionController.dispose();
    _modelVersionController.dispose();
    for (final map in _tipsControllers) {
      map['title']?.dispose();
      map['body']?.dispose();
    }
    for (final map in _issuesControllers) {
      map['title']?.dispose();
      map['body']?.dispose();
    }
    for (final map in _featuresControllers) {
      map['title']?.dispose();
      map['body']?.dispose();
    }
    _oodExplanationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config = await _service.fetchAll();
      if (mounted) {
        _appVersionController.text = config['app_version'] ?? '';
        _modelVersionController.text = config['model_version'] ?? '';
        
        _tipsControllers.clear();
        _issuesControllers.clear();
        _featuresControllers.clear();
        _oodExplanationController.text = '';

        final rawJson = config['help_content'] ?? '{}';
        try {
          final Map<String, dynamic> parsed = jsonDecode(rawJson);
          
          void populateList(String key, List<Map<String, TextEditingController>> controllers) {
            if (parsed[key] is List) {
              for (final item in parsed[key]) {
                controllers.add({
                  'title': TextEditingController(text: item['title']?.toString() ?? ''),
                  'body': TextEditingController(text: item['body']?.toString() ?? ''),
                });
              }
            }
          }

          populateList('tips', _tipsControllers);
          populateList('issues', _issuesControllers);
          populateList('features', _featuresControllers);
          _oodExplanationController.text = parsed['ood_explanation']?.toString() ?? '';
        } catch (e) {
          // If parsing fails, ignore and start with empty lists
        }

        setState(() => _loading = false);
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.upsert('app_version', _appVersionController.text.trim(),
          description: 'Current app version displayed in Settings → Support & About');
      await _service.upsert('model_version', _modelVersionController.text.trim(),
          description: 'Current ML model version displayed in Settings → Support & About');

      List<Map<String, String>> extractList(List<Map<String, TextEditingController>> controllers) {
        return controllers.map((map) => {
          'title': map['title']!.text.trim(),
          'body': map['body']!.text.trim(),
        }).toList();
      }

      final helpContentMap = {
        'tips': extractList(_tipsControllers),
        'issues': extractList(_issuesControllers),
        'features': extractList(_featuresControllers),
        'ood_explanation': _oodExplanationController.text.trim(),
      };
      
      final helpContentJson = jsonEncode(helpContentMap);

      await _service.upsert('help_content', helpContentJson,
          description:
              'Help & Tutorial content — JSON with tips, issues, features, ood_explanation');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration saved successfully.'),
            backgroundColor: AppTheme.botanicalPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                  : _buildForm(theme),
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
            color: theme.dividerColor.withOpacity(0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App Configuration',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Edit app version, model version, and help content.',
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
            tooltip: 'Reload from server',
            onPressed: _saving ? null : _load,
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(_saving ? 'Saving…' : 'Save'),
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
          Text('Failed to load configuration', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(_error ?? '',
              style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
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

  Widget _buildForm(ThemeData theme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // App Version
          _buildFieldLabel(theme, 'App Version'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _appVersionController,
            decoration: _inputDecoration('e.g. v1.0.28'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Displayed in Settings → Support & About. Update when a new APK is released.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),

          const SizedBox(height: 24),

          // Model Version
          _buildFieldLabel(theme, 'Model Version'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _modelVersionController,
            decoration: _inputDecoration('e.g. CNN v1.1'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Displayed in Settings → Support & About. Update after each model retraining.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),

          const SizedBox(height: 24),

          // Help Content
          _buildFieldLabel(theme, 'Help & Tutorial Content'),
          const SizedBox(height: 16),
          _buildDynamicSection(theme, 'Tips', _tipsControllers),
          const SizedBox(height: 24),
          _buildDynamicSection(theme, 'Issues', _issuesControllers),
          const SizedBox(height: 24),
          _buildDynamicSection(theme, 'Features', _featuresControllers),
          const SizedBox(height: 24),
          _buildFieldLabel(theme, 'Out-of-Distribution (OOD) Explanation'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _oodExplanationController,
            minLines: 4,
            maxLines: null,
            decoration: _inputDecoration('Explanation for unknown plant confidence...'),
            style: theme.textTheme.bodyMedium,
          ),

          const SizedBox(height: 32),

          // Save button at bottom
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Saving…' : 'Save Configuration'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.botanicalPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildDynamicSection(ThemeData theme, String title, List<Map<String, TextEditingController>> controllers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  controllers.add({
                    'title': TextEditingController(),
                    'body': TextEditingController(),
                  });
                });
              },
              icon: const Icon(Icons.add, size: 16),
              label: Text('Add $title'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (controllers.isEmpty)
          Text('No items added.', style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
        for (int i = 0; i < controllers.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: controllers[i]['title'],
                          decoration: _inputDecoration('Title'),
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            controllers[i]['title']?.dispose();
                            controllers[i]['body']?.dispose();
                            controllers.removeAt(i);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: controllers[i]['body'],
                    minLines: 2,
                    maxLines: null,
                    decoration: _inputDecoration('Body text'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFieldLabel(ThemeData theme, String label) {
    return Text(
      label,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    final theme = Theme.of(context);
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      contentPadding: const EdgeInsets.all(14),
    );
  }
}
