import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/prediction_result.dart';
import 'dart:io' show File, SocketException;
import 'dart:async';
import 'package:http_parser/http_parser.dart';
import 'api_config.dart';

class PredictionService {
  /// Get base URL from configuration
  /// 
  /// In development: Uses platform-specific localhost URLs
  /// In production: Uses deployed backend URL
  /// 
  /// Override with customUrl parameter for testing different endpoints
  static Future<String> getBaseUrl({String? customUrl, bool isProduction = false}) async {
    return ApiService.getBaseUrl(
      isProduction: isProduction,
      customUrl: customUrl,
    );
  }

  static Future<PredictionResult> predict(String imagePath, {String? customUrl, bool isProduction = false}) async {
    final baseUrl = await getBaseUrl(customUrl: customUrl, isProduction: isProduction);
    
    // Check backend health before proceeding
    try {
      final healthUri = Uri.parse('$baseUrl/health');
      final healthResponse = await http.get(healthUri).timeout(const Duration(seconds: 5));
      if (healthResponse.statusCode != 200) {
        throw Exception('Backend health check failed with status: ${healthResponse.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Cannot connect to IRIS AI Server. Please check your network connection.');
    } on SocketException {
      throw Exception('Cannot connect to IRIS AI Server. Please check your network connection.');
    } catch (e) {
      if (e.toString().contains('Cannot connect')) {
        rethrow;
      }
      throw Exception('Cannot connect to IRIS AI Server. Please check your network connection.');
    }

    final uri = Uri.parse('$baseUrl/predict');
    
    debugPrint('══════════════════════════════════════════');
    debugPrint('🔬 PREDICTION REQUEST');
    debugPrint('   URL: $uri');
    debugPrint('   Image: $imagePath');

    // Get the Firebase ID token
    final String token;
    try {
      token = await ApiService.getToken();
    } catch (e) {
      debugPrint('   ❌ Token retrieval failed: $e');
      debugPrint('══════════════════════════════════════════');
      throw Exception('Authentication failed: $e');
    }
    
    debugPrint('   Token: ${token.substring(0, 20)}... (${token.length} chars)');

    final file = File(imagePath);
    if (!await file.exists()) {
      debugPrint('   ❌ Image file not found at: $imagePath');
      debugPrint('══════════════════════════════════════════');
      throw Exception('Image file not found');
    }

    final fileBytes = await file.readAsBytes();
    final fileName = imagePath.split('/').last.split('\\').last;

    debugPrint('📸 IMAGE DIAGNOSTICS (Flutter):');
    debugPrint('   File path: $imagePath');
    debugPrint('   File size: ${fileBytes.length} bytes (${(fileBytes.length / 1024).toStringAsFixed(1)} KB)');
    debugPrint('   Upload filename: $fileName');

    final multipartFile = http.MultipartFile.fromBytes(
      'image',
      fileBytes,
      filename: imagePath.split('/').last.split('\\').last,
      contentType: MediaType('image', 'jpeg'),
    );

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(multipartFile);

    debugPrint('   Authorization header: Bearer ${token.substring(0, 20)}...');
    debugPrint('   Sending request...');

    try {
      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('   Response status: ${response.statusCode}');
      debugPrint('   Response body: ${response.body.length > 200 ? '${response.body.substring(0, 200)}...' : response.body}');
      debugPrint('══════════════════════════════════════════');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return PredictionResult.fromJson(data);
      } else if (response.statusCode == 422) {
        String errorType = '';
        String message = 'Validation failed.';
        
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded.containsKey('detail')) {
            final detail = decoded['detail'];
            if (detail is Map<String, dynamic>) {
              errorType = detail['error']?.toString() ?? '';
              message = detail['message']?.toString() ?? 'Validation failed.';
            } else if (detail is String) {
              message = detail;
            }
          }
        } catch (_) {
          // Ignore JSON decode error, fallback to throwing generic failure below
          throw Exception('Failed to analyze image: ${response.statusCode} - ${response.body}');
        }
        
        debugPrint("HTTP Status: ${response.statusCode}");
        debugPrint("Backend Message: $message");
        
        if (errorType == 'not_fundus') {
          throw Exception('BACKEND_VALIDATION_ERROR: Invalid Image Detected. Please upload a clear retinal fundus image for glaucoma analysis.');
        } else if (errorType == 'poor_quality') {
          throw Exception('BACKEND_VALIDATION_ERROR: Image Quality Insufficient. Please upload a clearer retinal fundus image.');
        }
        
        throw Exception('BACKEND_VALIDATION_ERROR: $message');
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Authentication failed (${response.statusCode}): ${response.body}');
      } else {
        throw Exception('Failed to analyze image: ${response.statusCode} - ${response.body}');
      }
    } on TimeoutException {
      debugPrint('   ❌ Request timeout');
      debugPrint('══════════════════════════════════════════');
      throw Exception('Cannot connect to IRIS AI Server. Please check your network connection.');
    } on SocketException catch (e) {
      debugPrint('   ❌ Socket error: $e');
      debugPrint('══════════════════════════════════════════');
      throw Exception('Cannot connect to IRIS AI Server. Please check your network connection.');
    } catch (e) {
      debugPrint('   ❌ Request error: $e');
      debugPrint('══════════════════════════════════════════');
      if (e is Exception && (e.toString().contains('BACKEND_VALIDATION_ERROR:') || e.toString().contains('Cannot connect'))) {
        rethrow;
      }
      throw Exception('Cannot connect to IRIS AI Server. Please check your network connection.');
    }
  }
}
