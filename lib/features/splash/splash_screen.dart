import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:herbascan/core/providers/app_provider.dart';
import 'package:herbascan/core/services/performance_monitor.dart';
import 'package:herbascan/core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _navigateToNextScreen();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    ));

    _animationController.forward();
  }

  Future<void> _navigateToNextScreen() async {
    await Future.delayed(const Duration(seconds: 3));

    // Stop tracking app start time
    final performanceMonitor = PerformanceMonitor();
    await performanceMonitor.stopTimer(PerformanceOperation.appStart);

    if (mounted) {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      if (appProvider.isFirstLaunch) {
        context.go('/onboarding');
      } else {
        context.go('/home');
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkScaffold : AppTheme.surfaceColor;
    final textSecondary = isDark ? Colors.white60 : AppTheme.textSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Centered hero content
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Leaf hero icon in circular container
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.botanicalPrimary.withOpacity(0.10),
                        ),
                        child: const Icon(
                          Icons.eco_rounded,
                          size: 80,
                          color: AppTheme.botanicalPrimary,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // App title
                      Text(
                        'HerbaScan',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Tagline
                      Text(
                        'Discover Philippine medicinal plants',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Linear progress indicator pinned to bottom edge
            Positioned(
              left: 0,
              right: 0,
              bottom: 32,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: SizedBox(
                    width: 200,
                    child: LinearProgressIndicator(
                      backgroundColor:
                          AppTheme.botanicalPrimary.withOpacity(0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.botanicalPrimary,
                      ),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
