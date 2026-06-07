import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:herbascan/core/services/tutorial_preferences.dart';
import 'package:herbascan/core/widgets/coachmark_card.dart';

/// Builds and shows the first-launch coachmark walkthrough for the home dashboard.
///
/// Three steps:
///   1. Hero "What plant are you identifying?" card        → introduces the dashboard.
///   2. Camera FAB                                          → key interaction (scan gesture).
///   3. Settings nav item                                   → profile / preferences entry point.
///
/// The tour auto-fires once on first /home visit (gated by [TutorialPreferences]) and
/// can be re-played from Settings via [TutorialPreferences.resetAll].
class HomeCoachmarkTour {
  HomeCoachmarkTour._();

  /// Show the tour against the supplied target keys. Caller is responsible for
  /// ensuring the keys are mounted in the widget tree before this is called
  /// (typically inside a post-frame callback).
  static void show({
    required BuildContext context,
    required GlobalKey heroKey,
    required GlobalKey fabKey,
    required GlobalKey recentScansKey,
    required GlobalKey settingsNavKey,
  }) {
    bool dontShowAgain = false;

    late final TutorialCoachMark tutorial;

    void finish({required bool completed}) async {
      await TutorialPreferences.setHomeTourDone();
      if (dontShowAgain) {
        await TutorialPreferences.setHomeDontShowAgain(true);
      }
    }

    tutorial = TutorialCoachMark(
      targets: [
        _buildTarget(
          identify: 'home_hero',
          keyTarget: heroKey,
          shape: ShapeLightFocus.RRect,
          radius: 18,
          align: ContentAlign.bottom,
          title: 'Tip:',
          body:
              'This is your dashboard. See recent scans, DOH-approved plants, and overall stats here.',
          onNext: () => tutorial.next(),
          onSkip: () => tutorial.skip(),
          onDontShowChanged: (v) => dontShowAgain = v,
        ),
        _buildTarget(
          identify: 'home_fab',
          keyTarget: fabKey,
          shape: ShapeLightFocus.Circle,
          radius: 36,
          align: ContentAlign.top,
          title: 'Tip:',
          body:
              'Tap the camera button to scan a plant. Hold the device steady for a clear photo.',
          onNext: () => tutorial.next(),
          onSkip: () => tutorial.skip(),
          onDontShowChanged: (v) => dontShowAgain = v,
        ),
        _buildTarget(
          identify: 'home_recent_scans',
          keyTarget: recentScansKey,
          shape: ShapeLightFocus.RRect,
          radius: 18,
          align: ContentAlign.bottom,
          title: 'Tip:',
          body:
              'Here are your recent scans. Tap any card to see details or "View All" for history.',
          onNext: () => tutorial.next(),
          onSkip: () => tutorial.skip(),
          onDontShowChanged: (v) => dontShowAgain = v,
        ),
        _buildTarget(
          identify: 'home_settings_nav',
          keyTarget: settingsNavKey,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          align: ContentAlign.top,
          title: 'Tip:',
          body:
              'Open Settings to manage preferences, sign in, or replay this tutorial anytime.',
          isLast: true,
          onNext: () => tutorial.next(),
          onSkip: () => tutorial.skip(),
          onDontShowChanged: (v) => dontShowAgain = v,
        ),
      ],
      colorShadow: Colors.black,
      opacityShadow: 0.78,
      paddingFocus: 6,
      hideSkip: true, // we render our own Skip button inside CoachmarkCard
      onFinish: () => finish(completed: true),
      onSkip: () {
        finish(completed: false);
        return true;
      },
    );

    tutorial.show(context: context);
  }

  static TargetFocus _buildTarget({
    required String identify,
    required GlobalKey keyTarget,
    required ShapeLightFocus shape,
    required double radius,
    required ContentAlign align,
    required String title,
    required String body,
    required VoidCallback onNext,
    required VoidCallback onSkip,
    required ValueChanged<bool> onDontShowChanged,
    bool isLast = false,
  }) {
    return TargetFocus(
      identify: identify,
      keyTarget: keyTarget,
      shape: shape,
      radius: radius,
      enableOverlayTab: false,
      contents: [
        TargetContent(
          align: align,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          builder: (context, controller) {
            return CoachmarkCard(
              title: title,
              body: body,
              isLast: isLast,
              onNext: onNext,
              onSkip: onSkip,
              onDontShowAgainChanged: onDontShowChanged,
            );
          },
        ),
      ],
    );
  }
}
