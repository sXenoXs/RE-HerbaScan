import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class GeminiPlantService {
  // TODO: Replace with your actual Gemini API key
  // Best practice: Store in .env file and load via flutter_dotenv
  static const String _apiKey = 'AIzaSyBX0__PUPyOPRGhcIMq9kY0nLq14Rs91yM';

  // Using Gemini 2.5 Flash - Latest and most efficient model
  static const String _modelName = 'gemini-2.5-flash';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/$_modelName:generateContent';

  /// Identifies a plant from image bytes using Gemini API
  /// Returns a Map containing predictions in the format expected by PlantResultScreen
  Future<Map<String, dynamic>> identifyPlant(Uint8List imageBytes) async {
    try {
      // Convert image to base64
      final base64Image = base64Encode(imageBytes);

      // Prepare the request body
      final requestBody = {
        "contents": [
          {
            "parts": [
              {
                "text": """You are a botanical expert. Analyze this plant image and identify it.

Respond ONLY with valid JSON in this exact format (no extra text, no markdown):
{

  "plantName": "Scientific name (Philippine local name)",
  "confidence": 0.95,
  "family": "Family name",
  "description": "Brief description",
  "characteristics": "Key features",
  "habitat": "Habitat info",
  "uses": "Uses",
  "caution": "Warnings if any"
}"""
              },
              {
                "inline_data": {
                  "mime_type": "image/jpeg",
                  "data": base64Image
                }
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.4,
          "topK": 32,
          "topP": 1,
          "maxOutputTokens": 8192,
        }
      };

      // Make the API request
      final url = Uri.parse('$_baseUrl?key=$_apiKey');
      print('🔗 Making request to: ${url.toString().replaceAll(_apiKey, 'API_KEY_HIDDEN')}');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        // Debug: Print full response
        print('📥 Full Gemini Response: ${jsonEncode(jsonResponse)}');

        // Check if candidates exist
        if (jsonResponse['candidates'] == null || jsonResponse['candidates'].isEmpty) {
          throw Exception('No candidates returned. Possible content filtering issue.');
        }

        // Check finish reason
        final finishReason = jsonResponse['candidates']?[0]?['finishReason'];
        if (finishReason == 'MAX_TOKENS') {
          print('⚠️ Warning: Response truncated due to MAX_TOKENS');
        } else if (finishReason == 'SAFETY') {
          throw Exception('Content was blocked by safety filters');
        }

        // Extract the generated text
        final content = jsonResponse['candidates']?[0]?['content'];
        final parts = content?['parts'];

        if (parts == null || parts.isEmpty) {
          print('❌ Error: No parts in response');
          print('Content: $content');
          throw Exception('Response has no content parts. Finish reason: $finishReason');
        }

        final generatedText = parts[0]['text'];

        if (generatedText == null || generatedText.toString().trim().isEmpty) {
          print('❌ Error: Text is null or empty');
          print('Parts: $parts');
          throw Exception('Generated text is empty. Finish reason: $finishReason');
        }

        print('✅ Generated text: $generatedText');

        // Parse the JSON response from Gemini
        final plantData = _parseGeminiResponse(generatedText);

        // Format for PlantResultScreen
        return {
          'predictions': [plantData],
          'method': 'gemini_api',
          'fallback_used': false,
          'gradcam_image': null, // Gemini doesn't provide heatmaps
        };
      } else {
        print('❌ API Error ${response.statusCode}: ${response.body}');
        throw Exception('Gemini API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error identifying plant: $e');
      rethrow;
    }
  }

  /// Alternative method with multiple plant suggestions
  Future<Map<String, dynamic>> identifyPlantWithAlternatives(Uint8List imageBytes) async {
    try {
      final base64Image = base64Encode(imageBytes);

      final requestBody = {
        "contents": [
          {
            "parts": [
              {
                "text": """You are a botanical expert. Analyze this plant and provide top 3 identifications.

Respond ONLY with valid JSON (no extra text, no markdown):
{
  "plants": [
    {
      "plantName": "Scientific (Common)",
      "confidence": 0.95,
      "family": "Family",
      "description": "Description",
      "characteristics": "Features",
      "habitat": "Habitat",
      "uses": "Uses",
      "caution": "Warnings"
    }
  ]
}

Provide up to 3 plants ordered by confidence."""
              },
              {
                "inline_data": {
                  "mime_type": "image/jpeg",
                  "data": base64Image
                }
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.4,
          "topK": 32,
          "topP": 1,
          "maxOutputTokens": 8192,
        }
      };

      final url = Uri.parse('$_baseUrl?key=$_apiKey');
      print('🔗 Making request to: ${url.toString().replaceAll(_apiKey, 'API_KEY_HIDDEN')}');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        // Debug: Print full response
        print('📥 Full Gemini Response (Multiple): ${jsonEncode(jsonResponse)}');

        final generatedText = jsonResponse['candidates']?[0]?['content']?['parts']?[0]?['text'];

        if (generatedText == null) {
          print('❌ Error: Could not extract text from response');
          print('Response structure: ${jsonResponse.keys}');
          if (jsonResponse['candidates'] != null) {
            print('Candidates: ${jsonResponse['candidates']}');
          }
          throw Exception('No response generated from Gemini API. Check logs for details.');
        }

        print('✅ Generated text: $generatedText');

        final plantData = _parseGeminiResponseMultiple(generatedText);

        return {
          'predictions': plantData,
          'method': 'gemini_api',
          'fallback_used': false,
          'gradcam_image': null,
        };
      } else {
        print('❌ API Error ${response.statusCode}: ${response.body}');
        throw Exception('Gemini API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error identifying plant with Gemini: $e');
      rethrow;
    }
  }

  /// Parse single plant response from Gemini
  Map<String, dynamic> _parseGeminiResponse(String generatedText) {
    try {
      // Clean the response - remove markdown code blocks if present
      String cleanedText = generatedText.trim();
      if (cleanedText.startsWith('```json')) {
        cleanedText = cleanedText.substring(7);
      }
      if (cleanedText.startsWith('```')) {
        cleanedText = cleanedText.substring(3);
      }
      if (cleanedText.endsWith('```')) {
        cleanedText = cleanedText.substring(0, cleanedText.length - 3);
      }
      cleanedText = cleanedText.trim();

      final parsed = jsonDecode(cleanedText);

      return {
        'plantName': parsed['plantName'] ?? 'Unknown Plant',
        'confidence': (parsed['confidence'] ?? 0.0).toDouble(),
        'family': parsed['family'] ?? 'Unknown Family',
        'description': parsed['description'] ?? 'No description available',
        'characteristics': parsed['characteristics'] ?? 'No characteristics available',
        'habitat': parsed['habitat'] ?? 'Unknown habitat',
        'uses': parsed['uses'] ?? 'No known uses',
        'caution': parsed['caution'] ?? 'No cautions',
      };
    } catch (e) {
      print('Error parsing Gemini response: $e');
      print('Raw response: $generatedText');

      // Fallback: Return basic info if parsing fails
      return {
        'plantName': 'Unable to identify',
        'confidence': 0.0,
        'family': 'Unknown',
        'description': generatedText,
        'characteristics': 'See description',
        'habitat': 'Unknown',
        'uses': 'Unknown',
        'caution': 'Unable to verify - consult an expert',
      };
    }
  }

  /// Parse multiple plant responses from Gemini
  List<Map<String, dynamic>> _parseGeminiResponseMultiple(String generatedText) {
    try {
      String cleanedText = generatedText.trim();
      if (cleanedText.startsWith('```json')) {
        cleanedText = cleanedText.substring(7);
      }
      if (cleanedText.startsWith('```')) {
        cleanedText = cleanedText.substring(3);
      }
      if (cleanedText.endsWith('```')) {
        cleanedText = cleanedText.substring(0, cleanedText.length - 3);
      }
      cleanedText = cleanedText.trim();

      final parsed = jsonDecode(cleanedText);
      final plants = parsed['plants'] as List;

      return plants.map((plant) {
        return {
          'plantName': plant['plantName'] ?? 'Unknown Plant',
          'confidence': (plant['confidence'] ?? 0.0).toDouble(),
          'family': plant['family'] ?? 'Unknown Family',
          'description': plant['description'] ?? 'No description available',
          'characteristics': plant['characteristics'] ?? 'No characteristics available',
          'habitat': plant['habitat'] ?? 'Unknown habitat',
          'uses': plant['uses'] ?? 'No known uses',
          'caution': plant['caution'] ?? 'No cautions',
        };
      }).toList();
    } catch (e) {
      print('Error parsing Gemini multiple response: $e');
      print('Raw response: $generatedText');

      return [
        {
          'plantName': 'Unable to identify',
          'confidence': 0.0,
          'family': 'Unknown',
          'description': generatedText,
          'characteristics': 'See description',
          'habitat': 'Unknown',
          'uses': 'Unknown',
          'caution': 'Unable to verify - consult an expert',
        }
      ];
    }
  }
}