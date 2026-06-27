import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:herbascan/core/services/model_inference_test_service.dart';
import 'package:herbascan/core/theme/app_theme.dart';

/// Admin Inference Testing Lab card — upload an image, run server-side
/// inference, and see full diagnostic output (OOD gate, Top-5, confidence gate).
class ModelInferenceTesterCard extends StatefulWidget {
  const ModelInferenceTesterCard({super.key});

  @override
  State<ModelInferenceTesterCard> createState() =>
      _ModelInferenceTesterCardState();
}

enum _TesterState { idle, picking, uploading, result }

class _ModelInferenceTesterCardState extends State<ModelInferenceTesterCard> {
  // ── Service ────────────────────────────────────────────────────────────────
  final _service = ModelInferenceTestService.instance;

  // ── State ──────────────────────────────────────────────────────────────────
  _TesterState _state = _TesterState.idle;
  double _temperature = 1.0;
  bool _showAdvanced = false;

  // Picked image
  Uint8List? _imageBytes;
  String? _imageFilename;

  // Result
  ModelInferenceResult? _result;
  String? _errorMessage;
  bool _isRateLimitError = false;

  // ── Helpers ────────────────────────────────────────────────────────────────
  bool get _isConfigured => _service.isConfigured;

  // ── Image picker (platform-aware) ──────────────────────────────────────────
  Future<(Uint8List, String)?> _pickImage() async {
    if (kIsWeb) {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.image, withData: true);
      if (result == null || result.files.isEmpty) return null;
      final f = result.files.first;
      if (f.bytes == null) return null;
      return (f.bytes!, f.name);
    } else {
      final xfile =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (xfile == null) return null;
      final bytes = await xfile.readAsBytes();
      return (bytes, xfile.name);
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<void> _onUploadImage() async {
    if (!_isConfigured) return;

    setState(() => _state = _TesterState.picking);

    final picked = await _pickImage();

    if (!mounted) return;
    if (picked == null) {
      setState(() => _state = _TesterState.idle);
      return;
    }

    final (bytes, name) = picked;
    setState(() {
      _imageBytes = bytes;
      _imageFilename = name;
      _state = _TesterState.uploading;
      _errorMessage = null;
      _isRateLimitError = false;
    });

    try {
      final result = await _service.testInference(
        imageBytes: bytes,
        filename: name,
        temperature: _temperature,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _state = _TesterState.result;
      });
    } on ModelInferenceTestException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isRateLimitError = e.code == 'rate_limited';
        _state = _TesterState.result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unexpected error: $e';
        _isRateLimitError = false;
        _state = _TesterState.result;
      });
    }
  }

  void _clearResults() {
    setState(() {
      _state = _TesterState.idle;
      _result = null;
      _imageBytes = null;
      _imageFilename = null;
      _errorMessage = null;
      _isRateLimitError = false;
    });
  }

  void _onRunAgain() {
    _clearResults();
    _onUploadImage();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.science_rounded,
                    color: Color(0xFF0D9488), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Model Inference Testing Lab',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Test the currently loaded Railway model with any plant image',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Not-configured banner ──────────────────────────────────────
          if (!_isConfigured)
            _NotConfiguredBanner(isDark: isDark),

          if (_isConfigured) ...[
            const SizedBox(height: 14),

            // ── Advanced: Temperature slider ─────────────────────────────
            _AdvancedPanel(
              temperature: _temperature,
              showAdvanced: _showAdvanced,
              onTemperatureChanged: (v) =>
                  setState(() => _temperature = v),
              onToggleAdvanced: () =>
                  setState(() => _showAdvanced = !_showAdvanced),
            ),

            const SizedBox(height: 12),

            // ── Upload button ────────────────────────────────────────────
            FilledButton.icon(
              onPressed: _state == _TesterState.uploading
                  ? null
                  : _onUploadImage,
              icon: _state == _TesterState.uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.upload_file_rounded, size: 20),
              label: Text(_state == _TesterState.uploading
                  ? 'Running inference…'
                  : 'Upload Test Image'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.botanicalPrimary,
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),

            // ── Image info strip ─────────────────────────────────────────
            if (_imageBytes != null && _imageFilename != null) ...[
              const SizedBox(height: 12),
              _ImageInfoStrip(
                imageBytes: _imageBytes!,
                filename: _imageFilename!,
                imageInfo: _result?.imageInfo,
              ),
            ],

            // ── Error display ────────────────────────────────────────────
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              _ErrorBanner(
                message: _errorMessage!,
                isRateLimit: _isRateLimitError,
              ),
            ],

            // ── Results panels ───────────────────────────────────────────
            if (_result != null) ...[
              const SizedBox(height: 14),

              // OOD Gate panel
              _OodGatePanel(
                ood: _result!.oodGate,
                stage1Rejected: _result!.stage1Rejected,
                isDark: isDark,
              ),

              if (_result!.top5.isNotEmpty && !_result!.stage1Rejected) ...[
                const SizedBox(height: 14),

                // Top-5 predictions panel
                _Top5Panel(
                  predictions: _result!.top5,
                  temperature: _result!.modelInfo.temperature,
                ),
              ],

              if (!_result!.stage1Rejected) ...[
                const SizedBox(height: 14),

                // Confidence gate row
                _ConfidenceGateRow(gate: _result!.confidenceGate),
              ],

              const SizedBox(height: 14),

              // Result banner
              _ResultBanner(
                result: _result!,
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _onRunAgain,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Run Again with New Image',
                          style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _clearResults,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Clear', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting widgets
// ─────────────────────────────────────────────────────────────────────────────

class _NotConfiguredBanner extends StatelessWidget {
  final bool isDark;
  const _NotConfiguredBanner({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.warningAmber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: AppTheme.warningAmber.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppTheme.warningAmber, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Backend not configured.\n'
                'Build with --dart-define=RAILWAY_BACKEND_URL=... '
                'and --dart-define=ADMIN_SECRET=...',
                style: TextStyle(fontSize: 12, color: AppTheme.warningAmber),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvancedPanel extends StatelessWidget {
  final double temperature;
  final bool showAdvanced;
  final ValueChanged<double> onTemperatureChanged;
  final VoidCallback onToggleAdvanced;

  const _AdvancedPanel({
    required this.temperature,
    required this.showAdvanced,
    required this.onTemperatureChanged,
    required this.onToggleAdvanced,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D9488).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggleAdvanced,
            borderRadius: BorderRadius.vertical(
                top: const Radius.circular(10),
                bottom: Radius.circular(showAdvanced ? 0 : 10)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    showAdvanced
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: const Color(0xFF0D9488),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Advanced',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0D9488).withValues(alpha: 0.9),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'T: ${temperature.toStringAsFixed(1)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0D9488),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showAdvanced)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text('0.1',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: const Color(0xFF0D9488),
                        thumbColor: const Color(0xFF0D9488),
                        overlayColor:
                            const Color(0xFF0D9488).withValues(alpha: 0.12),
                        inactiveTrackColor:
                            const Color(0xFF0D9488).withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: temperature,
                        min: 0.1,
                        max: 5.0,
                        divisions: 49,
                        label: temperature.toStringAsFixed(1),
                        onChanged: onTemperatureChanged,
                      ),
                    ),
                  ),
                  const Text('5.0',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ImageInfoStrip extends StatelessWidget {
  final Uint8List imageBytes;
  final String filename;
  final AdminImageInfo? imageInfo;

  const _ImageInfoStrip({
    required this.imageBytes,
    required this.filename,
    this.imageInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              imageBytes,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 56,
                height: 56,
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image_rounded,
                    size: 24, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  filename,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (imageInfo != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${imageInfo!.width} × ${imageInfo!.height} px',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OodGatePanel extends StatelessWidget {
  final OodGateResult ood;
  final bool stage1Rejected;
  final bool isDark;

  const _OodGatePanel({
    required this.ood,
    required this.stage1Rejected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF0D1117) : const Color(0xFF1A1A2E);
    final green = const Color(0xFF4ADE80);
    final red = const Color(0xFFF87171);

    final rows = [
      _GateMetricRow(
        label: 'Brightness',
        score: ood.brightness.toStringAsFixed(1),
        threshold: ood.brightnessMin.toStringAsFixed(1),
        passed: ood.brightnessPass,
        green: green,
        red: red,
      ),
      _GateMetricRow(
        label: 'Blur score',
        score: ood.blur.toStringAsFixed(1),
        threshold: ood.blurMin.toStringAsFixed(1),
        passed: ood.blurPass,
        green: green,
        red: red,
      ),
      _GateMetricRow(
        label: 'Edge dens ',
        score: ood.edgeDensity.toStringAsFixed(4),
        threshold: ood.edgeDensityMin.toStringAsFixed(3),
        passed: ood.edgeDensityPass,
        green: green,
        red: red,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ood.overallPass
              ? green.withValues(alpha: 0.3)
              : red.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'Courier',
          fontSize: 12.5,
          color: Color(0xFF4ADE80),
          height: 1.7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'OOD GATE:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...rows,
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    ood.overallPass
                        ? 'OOD gate PASSED'
                        : 'OOD gate FAILED — ${ood.failReason ?? "Unknown reason"}',
                    style: TextStyle(
                      color: ood.overallPass ? green : red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  ood.overallPass ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: ood.overallPass ? green : red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GateMetricRow extends StatelessWidget {
  final String label;
  final String score;
  final String threshold;
  final bool passed;
  final Color green;
  final Color red;

  const _GateMetricRow({
    required this.label,
    required this.score,
    required this.threshold,
    required this.passed,
    required this.green,
    required this.red,
  });

  @override
  Widget build(BuildContext context) {
    // Pad label to fixed width for alignment
    final padded = label.padRight(13);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Text('$padded: '),
          Text(
            score.padRight(9),
            style: TextStyle(
              color: passed ? green : red,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            passed ? 'PASS ' : 'FAIL ',
            style: TextStyle(
              color: passed ? green : red,
              fontWeight: FontWeight.bold,
            ),
          ),
          Icon(
            passed ? Icons.check : Icons.close,
            size: 13,
            color: passed ? green : red,
          ),
          const SizedBox(width: 4),
          Text(
            '(min $threshold)',
            style: TextStyle(
              color: green.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _Top5Panel extends StatelessWidget {
  final List<Top5Prediction> predictions;
  final double temperature;

  const _Top5Panel({
    required this.predictions,
    required this.temperature,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkCard : Colors.white;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'TOP-5 PREDICTIONS',
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(T=${temperature.toStringAsFixed(1)})',
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Divider(color: Colors.grey.withValues(alpha: 0.25), height: 1),
          const SizedBox(height: 8),
          ...predictions.map((p) => _PredictionRow(prediction: p)),
          const SizedBox(height: 4),
          Divider(color: Colors.grey.withValues(alpha: 0.25), height: 1),
        ],
      ),
    );
  }
}

class _PredictionRow extends StatefulWidget {
  final Top5Prediction prediction;
  const _PredictionRow({required this.prediction});

  @override
  State<_PredictionRow> createState() => _PredictionRowState();
}

class _PredictionRowState extends State<_PredictionRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.prediction;
    final isTop = p.rank == 1;
    final barColor = isTop
        ? AppTheme.botanicalPrimary
        : Colors.grey.withValues(alpha: 0.35);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '#${p.rank}',
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isTop ? AppTheme.botanicalPrimary : AppTheme.textSecondary,
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              p.label,
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 11.5,
                fontWeight: isTop ? FontWeight.w700 : FontWeight.w500,
                color: isTop ? null : AppTheme.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '${(p.confidence * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 11.5,
                fontWeight: isTop ? FontWeight.w700 : FontWeight.w500,
                color: isTop ? AppTheme.botanicalPrimary : AppTheme.textSecondary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, child) => ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: p.barFraction * _anim.value,
                  minHeight: 14,
                  backgroundColor: barColor.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(barColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceGateRow extends StatelessWidget {
  final ConfidenceGateResult gate;

  const _ConfidenceGateRow({required this.gate});

  @override
  Widget build(BuildContext context) {
    final pct = '${(gate.value * 100).toStringAsFixed(1)}%';
    final thr = '${(gate.threshold * 100).toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: gate.passed
            ? AppTheme.botanicalPrimary.withValues(alpha: 0.06)
            : AppTheme.warningAmber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: gate.passed
              ? AppTheme.botanicalPrimary.withValues(alpha: 0.25)
              : AppTheme.warningAmber.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            gate.passed ? Icons.check_circle_rounded : Icons.warning_rounded,
            size: 20,
            color: gate.passed
                ? AppTheme.botanicalPrimary
                : AppTheme.warningAmber,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'CONFIDENCE GATE: '),
                  TextSpan(
                    text: pct,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: gate.passed ? ' >= ' : ' < ',
                  ),
                  TextSpan(
                    text: thr,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (!gate.passed)
                    const TextSpan(
                      text: '  OOD — Not confident enough',
                    ),
                ],
              ),
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 12.5,
                color: gate.passed ? AppTheme.botanicalPrimary : Colors.orange.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  final ModelInferenceResult result;

  const _ResultBanner({required this.result});

  @override
  Widget build(BuildContext context) {
    final isPass =
        !result.oodRejected && !result.stage1Rejected && result.result != null;

    final Color bgColor;
    final Color borderColor;
    final IconData icon;
    final String text;

    if (isPass) {
      bgColor = AppTheme.botanicalPrimary.withValues(alpha: 0.08);
      borderColor = AppTheme.botanicalPrimary.withValues(alpha: 0.3);
      icon = Icons.check_circle_rounded;
      text = result.result != null
          ? 'RESULT:  ${result.result!.plantName}  (${result.result!.scientificName})'
          : 'RESULT:  —';
    } else {
      bgColor = AppTheme.warningAmber.withValues(alpha: 0.08);
      borderColor = AppTheme.warningAmber.withValues(alpha: 0.3);
      icon = Icons.warning_rounded;

      if (result.stage1Rejected) {
        text = 'OOD REJECTED — ${result.oodGate.failReason ?? "Image failed quality checks"}';
      } else if (result.oodRejected) {
        text = 'OOD REJECTED — Not confident enough';
      } else {
        text = 'OOD REJECTED';
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: isPass ? AppTheme.botanicalPrimary : AppTheme.warningAmber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isPass ? AppTheme.botanicalPrimary : Colors.orange.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final bool isRateLimit;

  const _ErrorBanner({required this.message, required this.isRateLimit});

  @override
  Widget build(BuildContext context) {
    final color = isRateLimit ? AppTheme.warningAmber : AppTheme.errorColor;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isRateLimit ? Icons.timer_rounded : Icons.error_outline_rounded,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
