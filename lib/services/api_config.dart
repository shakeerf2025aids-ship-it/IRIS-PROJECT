import 'dart:io' show Platform, Socket;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// API Configuration for different environments
abstract class ApiConfig {
  // ── Development URLs ──────────────────────────────────────────────
  static const String developmentAndroidEmulator = 'http://10.0.2.2:8000';
  static const String developmentAndroidDevice = 'http://10.62.220.83:8000'; // Updated: current laptop WiFi IP
  static const String developmentIOSSimulator = 'http://127.0.0.1:8000';
  static const String developmentIOSDevice = 'http://10.62.220.83:8000'; // Updated: current laptop WiFi IP
  static const String developmentDesktop = 'http://localhost:8000'; // Windows / macOS / Linux

  // ── Production endpoints ──────────────────────────────────────────
  static const String productionRender = 'https://iris-api.onrender.com';
  static const String productionRailway = 'https://iris-api.railway.app';
  static const String productionAWS = 'https://api.iris-glaucoma.com'; // Update with your domain
}

/// Environment-aware API service for managing base URLs
class ApiService {
  /// Cached result of the emulator detection (so we only probe once per session)
  static bool? _isEmulator;

  /// Detect whether the app is running on an Android emulator.
  ///
  /// Strategy: attempt a quick TCP connection to 10.0.2.2 (the host-loopback
  /// alias that only exists inside Android emulators). If it succeeds or at
  /// least resolves, we're on an emulator; otherwise we're on a physical device.
  static Future<bool> _detectIsEmulator() async {
    if (_isEmulator != null) return _isEmulator!;

    try {
      // Attempt to connect to the FastAPI dev server on 10.0.2.2.
      // If it's a physical device, this route doesn't exist/times out.
      final socket = await Socket.connect('10.0.2.2', 8000, timeout: const Duration(seconds: 1));
      socket.destroy();
      _isEmulator = true;
    } catch (_) {
      _isEmulator = false;
    }

    debugPrint('📱 Emulator detection: isEmulator=$_isEmulator');
    return _isEmulator!;
  }

  /// Get base URL based on environment and platform
  ///
  /// Priority:
  /// 1. Custom URL if provided
  /// 2. Platform-specific development URL (emulator vs physical device)
  /// 3. Fallback to localhost
  static Future<String> getBaseUrl({
    required bool isProduction,
    String? customUrl,
  }) async {
    // If custom URL is provided, use it
    if (customUrl != null && customUrl.isNotEmpty) {
      _logPlatformInfo(customUrl, 'Custom');
      return customUrl;
    }

    // Production environment
    if (isProduction) {
      _logPlatformInfo(ApiConfig.productionRender, 'Production');
      return ApiConfig.productionRender; // Change based on your deployment
    }

    // Development environment — platform-specific
    String baseUrl;

    if (Platform.isAndroid) {
      final isEmulator = await _detectIsEmulator();
      if (isEmulator) {
        baseUrl = ApiConfig.developmentAndroidEmulator;
        _logPlatformInfo(baseUrl, 'Android Emulator');
      } else {
        baseUrl = ApiConfig.developmentAndroidDevice;
        _logPlatformInfo(baseUrl, 'Android Physical Device');
      }
    } else if (Platform.isIOS) {
      // iOS simulator detection could be added here similarly
      baseUrl = ApiConfig.developmentIOSSimulator;
      _logPlatformInfo(baseUrl, 'iOS');
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      baseUrl = ApiConfig.developmentDesktop;
      _logPlatformInfo(baseUrl, 'Desktop');
    } else {
      baseUrl = 'http://localhost:8000';
      _logPlatformInfo(baseUrl, 'Fallback');
    }

    // Always print the selected URL to stdout for diagnostics
    debugPrint('Selected API URL: $baseUrl');
    return baseUrl;
  }

  /// Log platform and URL info for debugging connectivity issues
  static void _logPlatformInfo(String url, String environment) {
    debugPrint('══════════════════════════════════════════');
    debugPrint('🌐 API CONFIGURATION');
    debugPrint('   Environment : $environment');
    debugPrint('   API URL     : $url');
    debugPrint('   Platform    : ${Platform.operatingSystem}');
    debugPrint('   Is Android  : ${Platform.isAndroid}');
    debugPrint('   Is Emulator : ${_isEmulator ?? "not yet detected"}');
    debugPrint('══════════════════════════════════════════');
  }

  /// Get Firebase authentication token for API requests
  ///
  /// Returns the user's Firebase ID token if authenticated.
  /// Throws an exception if no user is logged in or token retrieval fails.
  static Future<String> getToken() async {
    final user = FirebaseAuth.instance.currentUser;

    debugPrint('══════════════════════════════════════════');
    debugPrint('🔑 TOKEN DEBUG');
    debugPrint('   User logged in: ${user != null}');
    debugPrint('   User UID: ${user?.uid}');
    debugPrint('   User email: ${user?.email}');

    if (user == null) {
      debugPrint('   ❌ No authenticated user — cannot get token');
      debugPrint('══════════════════════════════════════════');
      throw Exception('Not authenticated. Please log in first.');
    }

    try {
      // Get fresh Firebase ID token (force refresh)
      final token = await user.getIdToken(true);

      if (token == null || token.isEmpty) {
        debugPrint('   ❌ Firebase returned null/empty token');
        debugPrint('══════════════════════════════════════════');
        throw Exception('Failed to retrieve Firebase ID token');
      }

      debugPrint('   ✅ Token retrieved successfully');
      debugPrint('   Token length: ${token.length}');
      debugPrint('   Token prefix: ${token.substring(0, 20)}...');
      debugPrint('══════════════════════════════════════════');
      return token;
    } catch (e) {
      debugPrint('   ❌ Error getting Firebase token: $e');
      debugPrint('══════════════════════════════════════════');
      rethrow;
    }
  }
}
