import 'package:flutter/material.dart';
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

class _DisclaimerScreenState extends State<DisclaimerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _textFade;
  late Animation<double> _buttonFade;

  // Total: 2400 ms
  // Text fades in  → 0 – 800 ms  (interval 0.000 – 0.333)
  // Gap (silence)  → 800 – 1600 ms
  // Button fades in→ 1600 – 2400 ms (interval 0.667 – 1.000)
  static const Duration _totalDuration = Duration(milliseconds: 2400);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: _totalDuration,
      vsync: this,
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.333, curve: Curves.easeOutCubic),
      ),
    );

    _buttonFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.667, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;
    final subtextColor = isDark ? Colors.white70 : AppTheme.textSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // Shield icon
              FadeTransition(
                opacity: _textFade,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.botanicalPrimary.withValues(alpha: 0.10),
                  ),
                  child: const Icon(
                    Icons.health_and_safety_outlined,
                    size: 40,
                    color: AppTheme.botanicalPrimary,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Title
              FadeTransition(
                opacity: _textFade,
                child: Text(
                  'Medical Disclaimer',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    letterSpacing: -0.3,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Disclaimer body
              FadeTransition(
                opacity: _textFade,
                child: Text(
                  'Always consult a healthcare professional before using any '
                  'alternative remedies. This app is for educational purposes only.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: subtextColor,
                    height: 1.65,
                  ),
                ),
              ),

              const Spacer(),

              // Continue button — fades in 800 ms after text completes
              FadeTransition(
                opacity: _buttonFade,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _onContinue,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.botanicalPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Continue'),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
