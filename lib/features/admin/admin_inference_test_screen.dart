import 'package:flutter/material.dart';
import 'package:herbascan/features/admin/widgets/model_inference_tester_card.dart';

/// Standalone screen for the Inference Testing Lab.
class AdminInferenceTestScreen extends StatelessWidget {
  const AdminInferenceTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Inference Testing Lab',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: const ModelInferenceTesterCard(),
          ),
        ),
      ),
    );
  }
}
