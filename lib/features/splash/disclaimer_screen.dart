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
  String _disclaimerText = '';
  bool _isLoading = true;
  
  final ScrollController _scrollController = ScrollController();
  
  bool _hasScrolledToBottom = false;
  bool _agreedToDisclaimer = false;
  bool _agreedToToS = false;
  bool _agreedToEULA = false;

  @override
  void initState() {
    super.initState();
    _loadDisclaimer();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDisclaimer() async {
    try {
      final text = await rootBundle.loadString('assets/data/legal/Disclaimer.md');
      if (mounted) {
        setState(() {
          _disclaimerText = text;
          _isLoading = false;
        });
        // If text is too short to scroll, unlock immediately
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients &&
              _scrollController.position.maxScrollExtent <= 0) {
            setState(() {
              _hasScrolledToBottom = true;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _disclaimerText = 'Error loading disclaimer. Please try again later.';
          _isLoading = false;
        });
      }
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 20) {
        if (!_hasScrolledToBottom) {
          setState(() {
            _hasScrolledToBottom = true;
          });
        }
      }
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
    
    final bool canCheckToS = _agreedToDisclaimer;
    final bool canCheckEULA = _agreedToToS;
    final bool allChecked = _agreedToDisclaimer && _agreedToToS && _agreedToEULA;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        centerTitle: true,
        automaticallyImplyLeading: false,
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
                          data: _disclaimerText,
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
                child: Column(
                  children: [
                    if (!_hasScrolledToBottom)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(
                          'Please scroll to the bottom to unlock the checkboxes.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    CheckboxListTile(
                      enabled: _hasScrolledToBottom,
                      value: _agreedToDisclaimer,
                      onChanged: _hasScrolledToBottom
                          ? (val) {
                              setState(() {
                                _agreedToDisclaimer = val ?? false;
                                if (!_agreedToDisclaimer) {
                                  _agreedToToS = false;
                                  _agreedToEULA = false;
                                }
                              });
                            }
                          : null,
                      title: Text(
                        'I have read and agree to the Medical Disclaimer',
                        style: theme.textTheme.bodyMedium,
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      enabled: canCheckToS,
                      value: _agreedToToS,
                      onChanged: canCheckToS
                          ? (val) {
                              setState(() {
                                _agreedToToS = val ?? false;
                                if (!_agreedToToS) {
                                  _agreedToEULA = false;
                                }
                              });
                            }
                          : null,
                      title: Text(
                        'I have read and agree to the Terms of Service',
                        style: theme.textTheme.bodyMedium,
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      enabled: canCheckEULA,
                      value: _agreedToEULA,
                      onChanged: canCheckEULA
                          ? (val) {
                              setState(() {
                                _agreedToEULA = val ?? false;
                              });
                            }
                          : null,
                      title: Text(
                        'I have read and agree to the End-User License Agreement (EULA)',
                        style: theme.textTheme.bodyMedium,
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0).copyWith(top: 0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: allChecked ? _onContinue : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.botanicalPrimary,
                      disabledBackgroundColor: AppTheme.botanicalPrimary.withOpacity(0.3),
                      disabledForegroundColor: Colors.white70,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
