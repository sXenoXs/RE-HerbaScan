import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:herbascan/core/services/app_config_service.dart';
import 'package:herbascan/core/theme/app_theme.dart';
import 'package:herbascan/core/localization/app_localizations.dart';

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

  final List<Map<String, dynamic>> _tipsControllers = [];
  final List<Map<String, dynamic>> _issuesControllers = [];
  final List<Map<String, dynamic>> _featuresControllers = [];
  final TextEditingController _oodExplanationController = TextEditingController();

  static const List<String> _supportedIcons = [
    'wb_sunny',
    'filter_center_focus',
    'eco',
    'center_focus_strong',
    'crop_free',
    'image',
    'search',
    'verified',
    'medical_services',
    'history',
    'info',
  ];

  IconData? _iconFromName(String? name) {
    if (name == null || name.isEmpty) return null;
    switch (name) {
      case 'wb_sunny': return Icons.wb_sunny_rounded;
      case 'filter_center_focus': return Icons.filter_center_focus_rounded;
      case 'eco': return Icons.eco_rounded;
      case 'center_focus_strong': return Icons.center_focus_strong_rounded;
      case 'crop_free': return Icons.crop_free_rounded;
      case 'image': return Icons.image_rounded;
      case 'search': return Icons.search_rounded;
      case 'verified': return Icons.verified_rounded;
      case 'medical_services': return Icons.medical_services_rounded;
      case 'history': return Icons.history_rounded;
      case 'info': return Icons.info_outline;
      default: return Icons.eco_rounded;
    }
  }

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
      (map['title'] as TextEditingController?)?.dispose();
      (map['subtitle'] as TextEditingController?)?.dispose();
    }
    for (final map in _issuesControllers) {
      (map['title'] as TextEditingController?)?.dispose();
      (map['content'] as TextEditingController?)?.dispose();
    }
    for (final map in _featuresControllers) {
      (map['title'] as TextEditingController?)?.dispose();
      (map['subtitle'] as TextEditingController?)?.dispose();
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
          
          void populateList(String key, List<Map<String, dynamic>> controllers, List<String> fields) {
            if (parsed[key] is List) {
              for (final item in parsed[key]) {
                final map = <String, dynamic>{};
                for (final field in fields) {
                  if (field == 'icon') {
                    map['icon'] = item['icon']?.toString() ?? 'eco';
                  } else {
                    String text = item[field]?.toString() ?? '';
                    // Backward compatibility: if specific field is empty, fallback to 'body'
                    if (text.isEmpty && (field == 'subtitle' || field == 'content')) {
                      text = item['body']?.toString() ?? '';
                    }
                    map[field] = TextEditingController(text: text);
                  }
                }
                controllers.add(map);
              }
            }
          }

          populateList('tips', _tipsControllers, ['title', 'subtitle', 'icon']);
          populateList('issues', _issuesControllers, ['title', 'content']);
          populateList('features', _featuresControllers, ['title', 'subtitle', 'icon']);
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

      List<Map<String, String>> extractList(List<Map<String, dynamic>> controllers, List<String> fields) {
        return controllers.map((map) {
          final res = <String, String>{};
          for (final field in fields) {
            if (field == 'icon') {
              res['icon'] = map['icon'] as String;
            } else {
              res[field] = (map[field] as TextEditingController).text.trim();
            }
          }
          return res;
        }).toList();
      }

      final helpContentMap = {
        'tips': extractList(_tipsControllers, ['title', 'subtitle', 'icon']),
        'issues': extractList(_issuesControllers, ['title', 'content']),
        'features': extractList(_featuresControllers, ['title', 'subtitle', 'icon']),
        'ood_explanation': _oodExplanationController.text.trim(),
      };
      
      final helpContentJson = jsonEncode(helpContentMap);

      await _service.upsert('help_content', helpContentJson,
          description:
              'Help & Tutorial content — JSON with tips, issues, features, ood_explanation');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).configSavedSuccess),
            backgroundColor: AppTheme.botanicalPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context).failedToSave}: $e'),
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
                  AppLocalizations.of(context).appConfiguration,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  AppLocalizations.of(context).appConfigDesc,
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
            tooltip: AppLocalizations.of(context).reloadFromServer,
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
            label: Text(_saving ? AppLocalizations.of(context).saving : AppLocalizations.of(context).save),
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
          Text(AppLocalizations.of(context).failedToLoadConfig, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(_error ?? '',
              style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(AppLocalizations.of(context).retry),
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
          _buildFieldLabel(theme, AppLocalizations.of(context).appVersionLabel),
          const SizedBox(height: 8),
          TextFormField(
            controller: _appVersionController,
            decoration: _inputDecoration('e.g. v1.0.30'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context).appVersionDesc,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),

          const SizedBox(height: 24),

          // Model Version
          _buildFieldLabel(theme, AppLocalizations.of(context).modelVersionLabel),
          const SizedBox(height: 8),
          TextFormField(
            controller: _modelVersionController,
            decoration: _inputDecoration('e.g. CNN v1.1'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context).modelVersionDesc,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),

          const SizedBox(height: 24),

          // Help Content
          _buildFieldLabel(theme, AppLocalizations.of(context).helpTutorialContent),
          const SizedBox(height: 16),
          _buildDynamicSection(theme, AppLocalizations.of(context).tips, _tipsControllers, ['title', 'subtitle', 'icon']),
          const SizedBox(height: 24),
          _buildDynamicSection(theme, AppLocalizations.of(context).issues, _issuesControllers, ['title', 'content']),
          const SizedBox(height: 24),
          _buildDynamicSection(theme, AppLocalizations.of(context).features, _featuresControllers, ['title', 'subtitle', 'icon']),
          const SizedBox(height: 24),
          _buildFieldLabel(theme, AppLocalizations.of(context).oodExplanation),
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
              label: Text(_saving ? AppLocalizations.of(context).saving : AppLocalizations.of(context).saveConfiguration),
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

  Widget _buildDynamicSection(ThemeData theme, String title, List<Map<String, dynamic>> controllers, List<String> fields) {
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
                  final newItem = <String, dynamic>{};
                  for (final field in fields) {
                    if (field == 'icon') {
                      newItem['icon'] = 'eco';
                    } else {
                      newItem[field] = TextEditingController();
                    }
                  }
                  controllers.add(newItem);
                });
              },
              icon: const Icon(Icons.add, size: 16),
              label: Text('${AppLocalizations.of(context).add} $title'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (controllers.isEmpty)
          Text(AppLocalizations.of(context).noItemsAdded, style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
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
                            for (final field in fields) {
                              if (field != 'icon') {
                                (controllers[i][field] as TextEditingController?)?.dispose();
                              }
                            }
                            controllers.removeAt(i);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (fields.contains('icon')) ...[
                    DropdownButtonFormField<String>(
                      value: _supportedIcons.contains(controllers[i]['icon']) ? controllers[i]['icon'] : 'eco',
                      decoration: _inputDecoration('Icon'),
                      items: _supportedIcons.map((iconName) {
                        return DropdownMenuItem(
                          value: iconName,
                          child: Row(
                            children: [
                              Icon(_iconFromName(iconName), size: 18),
                              const SizedBox(width: 8),
                              Text(iconName),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            controllers[i]['icon'] = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (fields.contains('subtitle') || fields.contains('content')) ...[
                    TextFormField(
                      controller: controllers[i]['subtitle'] ?? controllers[i]['content'],
                      minLines: 2,
                      maxLines: null,
                      decoration: _inputDecoration(fields.contains('subtitle') ? 'Subtitle text' : 'Content text'),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
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
