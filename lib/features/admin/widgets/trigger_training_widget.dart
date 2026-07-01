import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TriggerTrainingWidget extends StatefulWidget {
  final String plantSlug;
  final String newClassName;

  const TriggerTrainingWidget({
    super.key,
    required this.plantSlug,
    required this.newClassName,
  });

  @override
  State<TriggerTrainingWidget> createState() => _TriggerTrainingWidgetState();
}

class _TriggerTrainingWidgetState extends State<TriggerTrainingWidget> {
  bool _isLoading = false;
  String? _statusMessage;
  bool _isError = false;

  /// Railway backend URL injected at build time via:
  ///   --dart-define=RAILWAY_BACKEND_URL=https://re-herbascan-production.up.railway.app
  static const String _railwayBackendUrl = String.fromEnvironment(
    'RAILWAY_BACKEND_URL',
    defaultValue: 'https://re-herbascan-production.up.railway.app',
  );

  /// Admin secret injected at build time via:
  ///   --dart-define=ADMIN_SECRET=<your_secret>
  static const String _adminSecret = String.fromEnvironment(
    'ADMIN_SECRET',
    defaultValue: '',
  );

  /// Returns true if required configuration is present.
  bool get _isConfigured =>
      _railwayBackendUrl.isNotEmpty && _adminSecret.isNotEmpty;

  Future<void> _triggerTraining() async {
    // Guard: show error if config is missing rather than making a broken call.
    if (!_isConfigured) {
      setState(() {
        _statusMessage = 'Configuration missing.\n'
            'Build with --dart-define=RAILWAY_BACKEND_URL=... '
            'and --dart-define=ADMIN_SECRET=...';
        _isError = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
      _isError = false;
    });

    try {
      final response = await http.post(
        Uri.parse('$_railwayBackendUrl/admin/trigger-training'),
        headers: {
          'Content-Type': 'application/json',
          'x-admin-secret': _adminSecret,
        },
        body: jsonEncode({
          'plant_slug': widget.plantSlug,
          'new_class_name': widget.newClassName,
        }),
      ).timeout(const Duration(seconds: 30));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        setState(() {
          _statusMessage = 'Training started for ${widget.newClassName}.\n'
              'Takes ~15 min. Check Modal dashboard for progress.';
          _isError = false;
        });
      } else {
        setState(() {
          _statusMessage = 'Error: ${body['detail'] ?? response.body}';
          _isError = true;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Request failed: $e';
        _isError = true;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.model_training, size: 18),
                const SizedBox(width: 8),
                Text('Train Model', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.newClassName} (${widget.plantSlug})',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _triggerTraining,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.rocket_launch_rounded, size: 18),
                label: Text(_isLoading ? 'Starting…' : 'Start Training'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isError
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isError
                        ? Colors.red.shade200
                        : Colors.green.shade200,
                  ),
                ),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: _isError
                        ? Colors.red.shade800
                        : Colors.green.shade800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
