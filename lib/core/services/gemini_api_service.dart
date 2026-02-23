import 'dart:convert';
import 'dart:typed_data';
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
  // Using v1 API with stable Gemini 2.5 Flash model
  // Reference: https://ai.google.dev/gemini-api/docs/models#gemini-2.5-flash
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1';
  static const String _model =
      'gemini-2.5-flash'; // Stable version - supports generateContent with multimodal inputs
  static const Duration timeout = Duration(seconds: 30);

  /// Generate an AI explanation for plant identification results
  ///
  /// Parameters:
  /// - plantName: Common name of the identified plant
  /// - scientificName: Scientific name of the plant
  /// - confidence: Confidence score (0-1)
  /// - predictions: List of top predictions with confidence scores
  /// - originalImageBytes: Original plant image bytes (for vision analysis)
  /// - heatmapImageBytes: Heatmap overlay image bytes (for biological marker analysis)
  /// - plantData: Optional Plant object for taxonomy, ecology, and safety data
  /// - isDangerousLookAlike: Whether this plant is a dangerous look-alike
  /// - dangerInfo: Information about dangerous look-alike markers
  ///
  /// Returns: Generated explanation text or null if error
  Future<String?> generateExplanation({
    required String plantName,
    required String scientificName,
    required double confidence,
    required List<Map<String, dynamic>> predictions,
    Uint8List? originalImageBytes,
    Uint8List? heatmapImageBytes,
    Plant? plantData,
    bool isDangerousLookAlike = false,
    Map<String, String>? dangerInfo,
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
        isDangerousLookAlike: isDangerousLookAlike,
        dangerInfo: dangerInfo,
      );

      // Prepare request with multimodal input (text + images)
      final url =
          Uri.parse('$_baseUrl/models/$_model:generateContent?key=$apiKey');

      // Build parts array with text and images
      final parts = <Map<String, dynamic>>[
        {'text': prompt}
      ];

      // Add original plant image if available
      if (originalImageBytes != null) {
        parts.add({
          'inlineData': {
            'mimeType': 'image/png',
            'data': _encodeImageToBase64(originalImageBytes),
          }
        });
      }

      // Add heatmap image if available
      if (heatmapImageBytes != null) {
        parts.add({
          'inlineData': {
            'mimeType': 'image/png',
            'data': _encodeImageToBase64(heatmapImageBytes),
          }
        });
      }

      final requestBody = {
        'contents': [
          {
            'parts': parts,
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 4096, // Increased for comprehensive explanations
        }
      };

      _logger.d(
          'Sending request to Gemini API for $plantName ($scientificName)...');
      _logger.d(
          'Request includes ${originalImageBytes != null ? "original image" : "no original image"} and ${heatmapImageBytes != null ? "heatmap image" : "no heatmap image"}');

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

          // Check finish reason
          final finishReason = candidate['finishReason'] as String?;
          if (finishReason == 'MAX_TOKENS') {
            _logger.w(
                'Response truncated due to MAX_TOKENS limit. Consider increasing maxOutputTokens.');
          }

          if (candidate.containsKey('content')) {
            final content = candidate['content'] as Map<String, dynamic>;
            if (content.containsKey('parts')) {
              final parts = content['parts'] as List;
              // Look for text in any part
              for (final part in parts) {
                if (part is Map<String, dynamic> && part.containsKey('text')) {
                  var explanation = part['text'] as String;
                  if (explanation.isNotEmpty) {
                    // Remove greeting text if present
                    explanation = _removeGreetingText(explanation);
                    _logger.i(
                        'Successfully generated explanation from Gemini API (${explanation.length} chars, finishReason: $finishReason)');
                    return explanation;
                  }
                }
              }
            }
          }
        }

        _logger.w(
            'Unexpected response format from Gemini API: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
        return null;
      } else {
        _logger.e(
            'Gemini API error: ${response.statusCode} - ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');
        return null;
      }
    } catch (e) {
      _logger.e('Error generating explanation from Gemini API: $e');
      return null;
    }
  }

  /// Encode image bytes to base64 string
  String _encodeImageToBase64(Uint8List imageBytes) {
    return base64Encode(imageBytes);
  }

  /// Build the prompt for Gemini API
  String _buildPrompt({
    required String plantName,
    required String scientificName,
    required double confidence,
    required List<Map<String, dynamic>> predictions,
    Plant? plantData,
    bool isDangerousLookAlike = false,
    Map<String, String>? dangerInfo,
  }) {
    final confidencePercent = (confidence * 100).toStringAsFixed(1);

    // Note: Only the top prediction (index 0) is passed from xai_explanation_service.dart
    // We don't use alternative predictions to avoid confusing Gemini - the model's decision is absolute truth.

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

    // Build safety check instructions for dangerous look-alikes
    String safetyCheckInstructions = '';
    if (isDangerousLookAlike && dangerInfo != null) {
      final marker = dangerInfo['marker'] ?? '';
      final safeAlternative = dangerInfo['safeAlternative'] ?? '';
      final safeMarker = dangerInfo['safeMarker'] ?? '';

      safetyCheckInstructions = '''

⚠️ CRITICAL SAFETY CHECK REQUIRED ⚠️

**CONTEXT**: The TFLite model has identified this as $plantName ($scientificName), which is a DANGEROUS LOOK-ALIKE that can be confused with $safeAlternative (the safe alternative).

**YOUR TASK - BIOLOGICAL MARKER VERIFICATION:**

The model's prediction is ABSOLUTE TRUTH. Your job is to verify the heatmap confirms the critical distinguishing marker.

**VERIFICATION REQUIRED:**

1. **Confirm the heatmap shows concentrated attention on $marker** - This is the CRITICAL distinguishing feature that confirms this is $plantName and NOT $safeAlternative.

2. **Explain why the heatmap pattern confirms the identification**: Reference the biological markers visible in the heatmap. The heatmap should show high attention (red/hot areas) on $marker, which is unique to $plantName.

3. **Safety Warning**: If the heatmap does NOT clearly show $marker, you must emphasize this may indicate a misidentification and the user should exercise extreme caution. However, still speak about $plantName as the identified plant - do not suggest it might be $safeAlternative.

**REMEMBER**: The model has already decided this is $plantName. You are verifying the heatmap supports this decision, not questioning it.

''';
    }

    return '''You are an Explainable AI (XAI) assistant specializing in biological model interpretation.

**CRITICAL CONTEXT - ABSOLUTE TRUTH:**
An onsite biological model (TFLite) has ALREADY identified this image as **$scientificName** ($plantName) with **$confidencePercent%** confidence.

**YOUR JOB - STRICT INSTRUCTIONS:**
- Do NOT try to identify the plant yourself. The model's prediction is ABSOLUTE TRUTH.
- Do NOT suggest alternative plant names or question the model's decision.
- Do NOT say "this appears to be" or "this might be" - speak definitively about $plantName.
- Your ONLY job is to explain WHY the model made this specific prediction based on the visual evidence in the provided heatmap.
- Never mention that you are an AI or that you are guessing. Speak definitively about the traits of $plantName.

**CRITICAL FORMATTING REQUIREMENTS:**
- DO NOT start with greetings, pleasantries, or introductory phrases.
- DO NOT use phrases like "Hello there!", "Thank you for sharing", "Let's dive into", "Welcome", or any similar conversational openings.
- START IMMEDIATELY with the "Plant Identification Summary" section.
- Begin your response directly with: **Plant Identification Summary** followed by the analysis.
- Be concise and professional in your tone.

**IMAGE ANALYSIS CONTEXT:**

You are analyzing TWO images provided:
1. **Original Plant Image**: The actual plant photograph captured by the user
2. **Heatmap Image**: A visualization showing where the TFLite model focused its attention during identification

The heatmap uses a color gradient:
- **Red/Hot areas**: Regions where the model focused heavily (key identifying features, disease spots, or distinctive characteristics)
- **Blue/Cool areas**: Regions with less attention

**CRITICAL**: Do NOT describe the images visually (e.g., "I see a green leaf"). Instead, explain what the HEATMAP reveals about the BIOLOGICAL MARKERS the model detected that confirm this is $plantName.

${taxonomyInfo.isNotEmpty ? '\n$taxonomyInfo' : ''}
${ecologyInfo.isNotEmpty ? '\n$ecologyInfo' : ''}
${safetyInfo.isNotEmpty ? '\n$safetyInfo' : ''}
${safetyCheckInstructions.isNotEmpty ? safetyCheckInstructions : ''}

**OUTPUT REQUIREMENTS - STRICT STRUCTURE:**

You MUST return your response using EXACTLY these four section headers in Markdown format. Do NOT deviate from this structure:

### Taxonomy
(List Kingdom, Family, Genus, Species)

### Ecology & Habitat
(Describe habitat and growth patterns)

### Medicinal Use & Preparation
(List specific traditional uses and step-by-step preparation if applicable)

### Safety & Look-alikes
(Analyze the heatmap image provided. Does this plant have toxic look-alikes? Explain the biological difference.)

**ANALYSIS REQUIRED FOR EACH SECTION:**

1. **Plant Identification Summary** (Before the structured sections):
   - Confirm that the visual traits of $plantName are present based on the heatmap analysis.
   - Explain: "The TFLite model identified this as $plantName ($scientificName) with $confidencePercent% confidence. Heatmap Analysis: The model focused heavily on [specific plant part as shown in heatmap]. This confirms the presence of [biological marker], a key distinguishing feature of $plantName."
   - Reference specific plant parts where the heatmap shows high attention.
   - Explain why these areas confirm the identification is correct.
   - Make the user feel like the analysis is based on actual heatmap data, not textbook information.

2. **### Taxonomy** (REQUIRED SECTION):
   ${plantData != null ? 'Include: Kingdom: Plantae, Family: ${plantData.family}, Genus: ${plantData.genus}, Species: ${plantData.species}' : 'If available, list the plant\'s taxonomic classification (Kingdom, Family, Genus, Species). If not available, state "Taxonomy information not available."'}

3. **### Ecology & Habitat** (REQUIRED SECTION):
   ${plantData != null && (plantData.ecology.isNotEmpty || plantData.habitat.isNotEmpty) ? 'Describe: ${plantData.ecology.isNotEmpty ? plantData.ecology : ""} ${plantData.habitat.isNotEmpty ? "Habitat: ${plantData.habitat}" : ""}' : 'If available, describe where this plant is typically found, its environmental requirements, and growth patterns. If not available, state "Ecology information not available."'}

4. **### Medicinal Use & Preparation** (REQUIRED SECTION):
   ${plantData != null && plantData.medicinalUses.isNotEmpty ? 'List specific traditional uses: ${plantData.medicinalUses.map((u) => u.condition).join(", ")}. ${plantData.preparationMethods.isNotEmpty ? "Preparation: ${plantData.preparationMethods.first.title}" : ""}' : 'If this is a medicinal plant, list specific traditional uses and step-by-step preparation methods if applicable. Mention if it\'s DOH-approved or traditionally used. If not a medicinal plant, state "Not traditionally used for medicinal purposes."'}

5. **### Safety & Look-alikes** (REQUIRED SECTION):
   ${isDangerousLookAlike && dangerInfo != null ? 'CRITICAL: This plant ($plantName) is a DANGEROUS LOOK-ALIKE. Analyze the heatmap image provided. Verify the heatmap shows the critical distinguishing marker: ${dangerInfo['marker']}. Explain the biological difference between $plantName and ${dangerInfo['safeAlternative']}. If the heatmap highlights ${dangerInfo['marker']}, this confirms the identification is correct. If the heatmap does NOT clearly show ${dangerInfo['marker']}, emphasize this may indicate a misidentification.' : plantData != null && plantData.safetyWarnings.isNotEmpty ? 'Include safety warnings: ${plantData.safetyWarnings.join(". ")}. ${plantData.isDOHApproved ? "This plant is DOH-approved for specific medicinal uses." : ""} If $plantName has known look-alikes, analyze the heatmap to confirm distinguishing features that separate $plantName from similar species.' : 'If this is a medicinal plant, mention any important safety considerations, contraindications, or warnings. Analyze the heatmap image provided. Does this plant have toxic look-alikes? Explain the biological difference. If no safety concerns, state "No known safety concerns when used as directed."'}

6. **Usability Assessment** (After the structured sections):
   Analyze the plant's condition based on heatmap patterns and provide a clear usability verdict:

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

**CRITICAL FORMATTING REQUIREMENTS:**
- You MUST use EXACTLY these four Markdown headers (###) in this exact order:
  1. ### Taxonomy
  2. ### Ecology & Habitat
  3. ### Medicinal Use & Preparation
  4. ### Safety & Look-alikes
- Each section MUST start with the header (###) followed by a blank line, then the content
- Do NOT use **bold** for these four section headers - use ### (h3) Markdown headers
- Write in a friendly, accessible tone suitable for general users
- Keep the explanation concise but informative (approximately 400-500 words total)
- Focus on practical information that helps users understand why the model made this identification
- Never question or suggest alternatives to the model's prediction
- Speak definitively about $plantName as if the identification is confirmed fact
- Use *italic* for emphasis when needed
- Use bullet points (- or *) for lists within sections
- Use proper line breaks between sections (blank lines)
- Keep paragraphs concise and well-structured
- Ensure proper spacing: blank line after headers, blank line between sections

**EXAMPLE OUTPUT STRUCTURE:**
```
**Plant Identification Summary**

[Your identification analysis here]

### Taxonomy

**Family:** [Family name]
**Genus:** [Genus name]
**Species:** [Species name]

### Ecology & Habitat

[Your ecology and habitat description here]

### Medicinal Use & Preparation

**Uses:** [List traditional uses]
**Preparation:** [Step-by-step preparation if applicable]

### Safety & Look-alikes

[Your safety analysis and look-alike information here]

**Usability Assessment**

**Status: [USABLE/USE WITH CAUTION/NOT RECOMMENDED]**

[Your usability analysis here]
```''';
  }

  /// Remove greeting text and introductory phrases from explanation
  String _removeGreetingText(String text) {
    String cleaned = text.trim();

    // Simple string-based removal for common greetings (more reliable than regex with apostrophes)
    final greetingPhrases = [
      'Hello there!',
      'Hello there',
      'Hello!',
      'Hello',
      'Hi there!',
      'Hi there',
      'Hi!',
      'Hi',
      'Thank you for sharing',
      'Thanks for sharing',
      'Let\'s dive into',
      'Lets dive into',
      'Let me',
      'I\'m here to',
      'Im here to',
      'Welcome',
    ];

    // Remove greeting phrases at the start (case-insensitive)
    for (final phrase in greetingPhrases) {
      if (cleaned.toLowerCase().startsWith(phrase.toLowerCase())) {
        cleaned = cleaned.substring(phrase.length).trim();
        // Also remove any trailing punctuation and spaces
        cleaned = cleaned.replaceFirst(RegExp(r'^[.,!?\s]+'), '').trim();
      }
    }

    // Remove common introductory sentence patterns
    final introPatterns = [
      RegExp(r'^Thank you for sharing[^.]*\.\s*', caseSensitive: false),
      RegExp(r'^Thanks for sharing[^.]*\.\s*', caseSensitive: false),
      RegExp(r'^Let\s+s\s+dive\s+into[^.]*\.\s*', caseSensitive: false),
      RegExp(r'^what the app detected[^.]*\.\s*', caseSensitive: false),
      RegExp(r'^what we can learn[^.]*\.\s*', caseSensitive: false),
    ];

    for (final pattern in introPatterns) {
      cleaned = cleaned.replaceFirst(pattern, '');
    }

    // Find the first meaningful content (usually starts with "**Plant Identification Summary**")
    final summaryPattern = RegExp(r'\*\*Plant Identification Summary\*\*');
    final summaryMatch = summaryPattern.firstMatch(cleaned);
    if (summaryMatch != null && summaryMatch.start > 0) {
      // If we found the summary section but there's text before it, remove everything before it
      cleaned = cleaned.substring(summaryMatch.start).trim();
    }

    return cleaned.trim();
  }

  /// Check if Gemini API is available (API key configured)
  Future<bool> isAvailable() async {
    return await ConfigService.isGeminiApiKeyConfigured();
  }
}
