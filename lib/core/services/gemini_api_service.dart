import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'config_service.dart';
import '../models/plant.dart';

/// Service for communicating with Google Gemini API for generating AI explanations
class GeminiAPIService {
  static final GeminiAPIService _instance = GeminiAPIService._internal();
  factory GeminiAPIService() => _instance;
  GeminiAPIService._internal();

  final Logger _logger = Logger();
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';
  static const String _model =
      'gemini-1.5-flash'; // Updated to use available model
  static const Duration timeout = Duration(seconds: 30);

  /// Generate an AI explanation for plant identification results
  ///
  /// Parameters:
  /// - plantName: Common name of the identified plant
  /// - scientificName: Scientific name of the plant
  /// - confidence: Confidence score (0-1)
  /// - predictions: List of top predictions with confidence scores
  /// - imagePath: Optional path to the plant image
  /// - plantData: Optional Plant object for taxonomy, ecology, and safety data
  ///
  /// Returns: Generated explanation text or null if error
  Future<String?> generateExplanation({
    required String plantName,
    required String scientificName,
    required double confidence,
    required List<Map<String, dynamic>> predictions,
    String? imagePath,
    Plant? plantData,
  }) async {
    try {
      // Check if API key is configured
      final apiKey = await ConfigService.getGeminiApiKey();
      if (apiKey.isEmpty || !await ConfigService.isGeminiApiKeyConfigured()) {
        _logger.w('Gemini API key not configured');
        return null;
      }

      // Build the prompt
      final prompt = _buildPrompt(
        plantName: plantName,
        scientificName: scientificName,
        confidence: confidence,
        predictions: predictions,
        plantData: plantData,
      );

      // Prepare request
      final url =
          Uri.parse('$_baseUrl/models/$_model:generateContent?key=$apiKey');

      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 1024,
        }
      };

      _logger.d('Sending request to Gemini API...');

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Extract the generated text from the response
        if (data.containsKey('candidates') &&
            (data['candidates'] as List).isNotEmpty) {
          final candidate = (data['candidates'] as List).first;
          if (candidate.containsKey('content') &&
              candidate['content'].containsKey('parts')) {
            final parts = candidate['content']['parts'] as List;
            if (parts.isNotEmpty && parts.first.containsKey('text')) {
              final explanation = parts.first['text'] as String;
              _logger.i('Successfully generated explanation from Gemini API');
              return explanation;
            }
          }
        }

        _logger.w('Unexpected response format from Gemini API');
        return null;
      } else {
        _logger
            .e('Gemini API error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      _logger.e('Error generating explanation from Gemini API: $e');
      return null;
    }
  }

  /// Build the prompt for Gemini API
  String _buildPrompt({
    required String plantName,
    required String scientificName,
    required double confidence,
    required List<Map<String, dynamic>> predictions,
    Plant? plantData,
  }) {
    final confidencePercent = (confidence * 100).toStringAsFixed(1);

    // Build top predictions list
    final predictionsText = StringBuffer();
    for (int i = 0; i < predictions.length && i < 3; i++) {
      final pred = predictions[i];
      final predName = pred['label'] ?? pred['plant_name'] ?? 'Unknown';
      final predConf = pred['confidence'] ?? 0.0;
      final predConfPercent = (predConf * 100).toStringAsFixed(1);
      predictionsText.writeln('${i + 1}. $predName (${predConfPercent}%)');
    }

    // Build taxonomy, ecology, and safety information if plant data is available
    String taxonomyInfo = '';
    String ecologyInfo = '';
    String safetyInfo = '';

    if (plantData != null) {
      taxonomyInfo = '''
**Taxonomy Information Available:**
- Kingdom: Plantae
- Family: ${plantData.family}
- Genus: ${plantData.genus}
- Species: ${plantData.species}
''';

      if (plantData.ecology.isNotEmpty || plantData.habitat.isNotEmpty) {
        ecologyInfo = '''
**Ecology & Habitat Information Available:**
${plantData.ecology.isNotEmpty ? '- Ecology: ${plantData.ecology}' : ''}
${plantData.habitat.isNotEmpty ? '- Habitat: ${plantData.habitat}' : ''}
''';
      }

      if (plantData.safetyWarnings.isNotEmpty) {
        safetyInfo = '''
**Safety Warnings Available:**
${plantData.safetyWarnings.map((w) => '- $w').join('\n')}
${plantData.isDOHApproved ? '\n✅ This plant is DOH-approved for specific medicinal uses.' : ''}
''';
      }
    }

    return '''You are an expert botanist and herbal medicine specialist. Provide a clear, informative, and empathetic explanation about a plant identification result from a mobile app.

Plant Identification Results:
- Identified Plant: $plantName ($scientificName)
- Confidence: $confidencePercent%
- Top Predictions:
$predictionsText
${taxonomyInfo.isNotEmpty ? '\n$taxonomyInfo' : ''}
${ecologyInfo.isNotEmpty ? '\n$ecologyInfo' : ''}
${safetyInfo.isNotEmpty ? '\n$safetyInfo' : ''}

IMPORTANT: The app uses a GradCAM/CAM heatmap visualization that highlights areas of the plant image where the AI model focused its attention. Red/hot areas in the heatmap typically indicate:
- Disease spots or lesions
- Brown or damaged plant parts
- Unusual patterns that may indicate health issues
- Key identifying features

Please provide a comprehensive explanation that includes:

1. **Plant Identification Summary**: Explain what the model detected and why it identified this plant, mentioning key visual features that match typical characteristics of $plantName. Reference the heatmap if it shows distinctive patterns.

2. **Taxonomy**: ${plantData != null ? 'Include the taxonomy information provided above (Kingdom, Family, Genus, Species).' : 'If available, mention the plant\'s taxonomic classification (Family, Genus, Species).'}

3. **Ecology & Habitat**: ${plantData != null && (plantData.ecology.isNotEmpty || plantData.habitat.isNotEmpty) ? 'Include the ecology and habitat information provided above.' : 'If available, mention where this plant is typically found and its environmental requirements.'}

4. **Medicinal Uses Overview**: If this is a medicinal plant, briefly summarize its main medicinal uses and active compounds. Mention if it's DOH-approved or traditionally used. ${plantData != null && plantData.medicinalUses.isNotEmpty ? 'Reference the medicinal uses information provided above.' : ''}

5. **Safety Information**: ${plantData != null && plantData.safetyWarnings.isNotEmpty ? 'Include the safety warnings provided above. This is CRITICAL for user safety.' : 'If this is a medicinal plant, mention any important safety considerations, contraindications, or warnings.'}

6. **Usability Assessment**: This is CRITICAL - Analyze the plant's condition and provide a clear usability verdict:

   **Format the Usability Assessment as follows:**
   
   **Status: [USABLE / USE WITH CAUTION / NOT RECOMMENDED]**
   
   Then provide:
   - Analysis of plant condition based on the heatmap patterns (if heatmap shows concentrated red areas, this may indicate disease, brown spots, or damage)
   - Whether the plant appears healthy or shows signs of disease/damage
   - Specific guidance on usability:
     * If USABLE: Confirm the plant appears healthy and safe for use
     * If USE WITH CAUTION: Note any concerns (low confidence, possible disease signs, etc.)
     * If NOT RECOMMENDED: Explain why (severe disease, damage, or safety concerns)
   - Recommendations for use (if usable) or what to look for before using

Write in a friendly, accessible tone suitable for general users. Keep the explanation concise but informative (approximately 350-450 words). Focus on practical information that helps users understand the identification result and make informed decisions about using the plant.

Format your response using Markdown:
- Use **bold** for section headers (e.g., **Plant Identification Summary**, **Taxonomy**, **Ecology & Habitat**, **Medicinal Uses Overview**, **Safety Information**, **Usability Assessment**)
- For Usability Assessment, start with **Status: [USABLE/USE WITH CAUTION/NOT RECOMMENDED]** in bold
- Add a blank line after each bold header before the content
- Use *italic* for emphasis when needed
- Use bullet points (- or *) for lists
- Use proper line breaks between sections (blank lines)
- Keep paragraphs concise and well-structured
- Ensure proper spacing: blank line after headers, blank line between sections''';
  }

  /// Check if Gemini API is available (API key configured)
  Future<bool> isAvailable() async {
    return await ConfigService.isGeminiApiKeyConfigured();
  }
}
