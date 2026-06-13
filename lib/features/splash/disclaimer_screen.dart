import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:herbascan/core/theme/app_theme.dart';

const String kDisclaimerAcknowledgedKey = 'disclaimer_acknowledged';

class DisclaimerScreen extends StatefulWidget {
  /// 'home', 'admin', or 'onboarding' — set by the splash screen before routing here.
  final String destination;

  const DisclaimerScreen({super.key, required this.destination});

  @override
  State<DisclaimerScreen> createState() => _DisclaimerScreenState();
}

class _DisclaimerScreenState extends State<DisclaimerScreen> {
  final List<String> _assetPaths = [
    'assets/data/legal/Disclaimer.md',
    'assets/data/legal/Terms of Service.md',
    'assets/data/legal/End-User License Agreement.md',
  ];

  final List<String> _checkboxLabels = [
    'I have read and agree to the Medical Disclaimer',
    'I have read and agree to the Terms of Service',
    'I have read and agree to the End-User License Agreement (EULA)',
  ];

  List<String> _markdownTexts = ['', '', ''];
  bool _isLoading = true;

  final ScrollController _scrollController = ScrollController();

  int _currentStep = 0;
  List<bool> _hasScrolledToBottom = [false, false, false];
  List<bool> _agreed = [false, false, false];

  @override
  void initState() {
    super.initState();
    _loadAllTexts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAllTexts() async {
    try {
      for (int i = 0; i < _assetPaths.length; i++) {
        _markdownTexts[i] = await rootBundle.loadString(_assetPaths[i]);
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _checkIfShortText();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _markdownTexts[0] = 'Error loading documents. Please try again later.';
          _isLoading = false;
        });
      }
    }
  }

  void _checkIfShortText() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent <= 0) {
        setState(() {
          _hasScrolledToBottom[_currentStep] = true;
        });
      }
    });
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 20) {
        if (!_hasScrolledToBottom[_currentStep]) {
          setState(() {
            _hasScrolledToBottom[_currentStep] = true;
          });
        }
      }
    }
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
      // Scroll to top for the new text
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
        _checkIfShortText();
      });
    } else {
      _onContinue();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
        _checkIfShortText();
      });
    }
  }

  Future<void> _onContinue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kDisclaimerAcknowledgedKey, true);
    if (mounted) {
      context.go('/${widget.destination}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkScaffold : AppTheme.surfaceColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Terms & Conditions (${_currentStep + 1}/3)'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _prevStep,
              )
            : null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Expanded(
                child: Card(
                  margin: const EdgeInsets.all(16.0),
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Markdown(
                          controller: _scrollController,
                          data: _markdownTexts[_currentStep],
                          styleSheet: MarkdownStyleSheet(
                            p: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: SizedBox(
                  // Fixed height to prevent layout jumps when checkbox appears
                  height: 60,
                  child: Center(
                    child: !_hasScrolledToBottom[_currentStep]
                        ? Text(
                            'Please scroll to the bottom to unlock the agreement.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : CheckboxListTile(
                            value: _agreed[_currentStep],
                            onChanged: (val) {
                              setState(() {
                                _agreed[_currentStep] = val ?? false;
                              });
                            },
                            title: Text(
                              _checkboxLabels[_currentStep],
                              style: theme.textTheme.bodyMedium,
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0).copyWith(top: 0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _agreed[_currentStep] ? _nextStep : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.botanicalPrimary,
                      disabledBackgroundColor:
                          AppTheme.botanicalPrimary.withOpacity(0.3),
                      disabledForegroundColor: Colors.white70,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentStep < 2 ? 'Next' : 'Continue',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
