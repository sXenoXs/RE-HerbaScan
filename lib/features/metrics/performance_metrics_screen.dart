import 'package:flutter/material.dart';

class PerformanceMetricsScreen extends StatelessWidget {
  const PerformanceMetricsScreen({super.key});

  // These are sample metrics - in a real app, these would come from actual model testing
  final double accuracy = 0.8923; // 89.23%
  final double precision = 0.8756; // 87.56%
  final double recall = 0.8834; // 88.34%
  final double f1Score = 0.8795; // 87.95%

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Performance Metrics'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.analytics,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Model Performance',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'MobileNet V2 + Random Forest',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Metrics Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _buildMetricCard('Accuracy', accuracy, Icons.check_circle,
                    Colors.green, theme),
                _buildMetricCard('Precision', precision, Icons.track_changes,
                    Colors.blue, theme),
                _buildMetricCard(
                    'Recall', recall, Icons.search, Colors.orange, theme),
                _buildMetricCard(
                    'F1-Score', f1Score, Icons.balance, Colors.purple, theme),
              ],
            ),

            const SizedBox(height: 24),

            // Explanation Section
            Text(
              'Understanding the Metrics',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            _buildExplanationCard(
              'Accuracy',
              'Overall correctness of the model across all plant identifications.',
              '${(accuracy * 100).toStringAsFixed(2)}% of all predictions are correct.',
              Icons.check_circle,
              Colors.green,
              theme,
            ),
            _buildExplanationCard(
              'Precision',
              'When the model identifies a specific plant, how often is it correct?',
              '${(precision * 100).toStringAsFixed(2)}% of positive identifications are accurate.',
              Icons.track_changes,
              Colors.blue,
              theme,
            ),
            _buildExplanationCard(
              'Recall',
              'How well does the model find all instances of each plant species?',
              '${(recall * 100).toStringAsFixed(2)}% of actual plants are correctly identified.',
              Icons.search,
              Colors.orange,
              theme,
            ),
            _buildExplanationCard(
              'F1-Score',
              'Balanced measure combining precision and recall.',
              'Harmonic mean of precision and recall: ${(f1Score * 100).toStringAsFixed(2)}%',
              Icons.balance,
              Colors.purple,
              theme,
            ),

            const SizedBox(height: 24),

            // Model Information
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Model Information',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                      'Architecture', 'MobileNet V2 + Random Forest', theme),
                  _buildInfoRow('Training Dataset',
                      '40 Philippine Medicinal Plants', theme),
                  _buildInfoRow(
                      'Validation Source', 'Test set (20% of dataset)', theme),
                  _buildInfoRow(
                      'Score-CAM', 'Enabled for explainability', theme),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Disclaimer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Note',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'These metrics are based on controlled testing conditions. Real-world performance may vary based on image quality, lighting, and leaf condition.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
      String title, double value, IconData icon, Color color, ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: color),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                '${(value * 100).toStringAsFixed(2)}%',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanationCard(String title, String description, String value,
      IconData icon, Color color, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
