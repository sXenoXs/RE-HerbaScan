// lib/features/scan/plant_result_screen.dart
import 'package:flutter/material.dart';
import 'package:herbascan/core/widgets/gradcam_visualization.dart';
import 'package:herbascan/core/localization/app_localizations.dart';
import 'dart:io';

class PlantResultScreen extends StatefulWidget {
  final String imagePath;
  final List<Map<String, dynamic>> predictions;
  final String? gradCAMPath;
  final String? summaryGradCAMPath;

  const PlantResultScreen({
    super.key,
    required this.imagePath,
    required this.predictions,
    this.gradCAMPath,
    this.summaryGradCAMPath,
  });

  @override
  State<PlantResultScreen> createState() => _PlantResultScreenState();
}

class _PlantResultScreenState extends State<PlantResultScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (widget.predictions.isEmpty) {
      return _buildErrorScreen();
    }

    final topPrediction = widget.predictions.first;
    final plantName = topPrediction['plantName'] ?? 'Unknown Plant';
    final confidence = (topPrediction['confidence'] ?? 0.0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).scanResults),
        actions: [
          IconButton(
            onPressed: _shareResults,
            icon: const Icon(Icons.share),
            tooltip: 'Share Results',
          ),
          IconButton(
            onPressed: _saveResults,
            icon: const Icon(Icons.save),
            tooltip: 'Save Results',
          ),
        ],
      ),
      body: Column(
        children: [
          // Plant identification result
          _buildPlantResultCard(theme, plantName, confidence),
          
          // Tab bar
          TabBar(
            controller: _tabController,
            tabs: [
              const Tab(
                icon: Icon(Icons.info),
                text: 'Details',
              ),
              Tab(
                icon: const Icon(Icons.visibility),
                text: 'AI Explanation',
              ),
            ],
          ),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDetailsTab(theme, topPrediction),
                _buildGradCAMTab(theme, plantName, confidence),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).scanResults),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No predictions available',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to identify the plant in the image',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantResultCard(ThemeData theme, String plantName, double confidence) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor.withOpacity(0.1),
            theme.primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Plant image
          Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(widget.imagePath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade100,
                    child: Icon(
                      Icons.local_florist,
                      size: 48,
                      color: theme.primaryColor,
                    ),
                  );
                },
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Plant name
          Text(
            plantName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Confidence score
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getConfidenceColor(confidence).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _getConfidenceColor(confidence).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.analytics,
                  size: 16,
                  color: _getConfidenceColor(confidence),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(confidence * 100).toStringAsFixed(1)}% Confidence',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getConfidenceColor(confidence),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(ThemeData theme, Map<String, dynamic> topPrediction) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top predictions
          _buildPredictionsCard(theme),
          
          const SizedBox(height: 16),
          
          // Plant information
          _buildPlantInfoCard(theme, topPrediction),
          
          const SizedBox(height: 16),
          
          // Scan metadata
          _buildMetadataCard(theme),
        ],
      ),
    );
  }

  Widget _buildGradCAMTab(ThemeData theme, String plantName, double confidence) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // GradCAM visualization
          GradCAMVisualization(
            gradCAMPath: widget.gradCAMPath,
            summaryGradCAMPath: widget.summaryGradCAMPath,
            originalImagePath: widget.imagePath,
            plantName: plantName,
            confidence: confidence,
            onRefresh: _regenerateGradCAM,
          ),
          
          const SizedBox(height: 16),
          
          // GradCAM info
          _buildGradCAMInfoCard(theme),
        ],
      ),
    );
  }

  Widget _buildPredictionsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: theme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Top Predictions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...widget.predictions.asMap().entries.map((entry) {
              final index = entry.key;
              final prediction = entry.value;
              final confidence = (prediction['confidence'] ?? 0.0).toDouble();
              final plantName = prediction['plantName'] ?? 'Unknown';
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plantName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${(confidence * 100).toStringAsFixed(1)}% confidence',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 60,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: confidence.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _getConfidenceColor(confidence),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantInfoCard(ThemeData theme, Map<String, dynamic> prediction) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: theme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Plant Information',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Scientific Name', prediction['scientificName'] ?? 'Unknown'),
            _buildInfoRow('Confidence Level', _getConfidenceLevel((prediction['confidence'] ?? 0.0).toDouble())),
            _buildInfoRow('Prediction Index', '${prediction['index'] ?? 'N/A'}'),
            _buildInfoRow('Features', '${(prediction['features'] as Map?)?.length ?? 0} features detected'),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: theme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Scan Information',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Scan Time', DateTime.now().toString().split('.')[0]),
            _buildInfoRow('Image Path', widget.imagePath.split('/').last),
            _buildInfoRow('GradCAM Available', widget.gradCAMPath != null ? 'Yes' : 'No'),
            _buildInfoRow('Summary GradCAM', widget.summaryGradCAMPath != null ? 'Yes' : 'No'),
          ],
        ),
      ),
    );
  }

  Widget _buildGradCAMInfoCard(ThemeData theme) {
          return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline, color: theme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'About GradCAM',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'GradCAM (Gradient-weighted Class Activation Mapping) shows which parts of the image the AI model focused on when making its prediction. This helps explain why the model made its decision.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              '• Red areas: High attention (important features)\n'
              '• Green areas: Medium attention\n'
              '• Blue areas: Low attention',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.5) return Colors.orange;
    return Colors.red;
  }

  String _getConfidenceLevel(double confidence) {
    if (confidence >= 0.8) return 'High';
    if (confidence >= 0.5) return 'Medium';
    return 'Low';
  }

  void _regenerateGradCAM() {
    // TODO: Implement GradCAM regeneration
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('GradCAM regeneration not implemented yet'),
      ),
    );
  }

  void _shareResults() {
    // TODO: Implement sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality not implemented yet'),
      ),
    );
  }

  void _saveResults() {
    // TODO: Implement save functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Save functionality not implemented yet'),
      ),
    );
  }
}