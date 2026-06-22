import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../../core/localization/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/top_controls.dart';
import '../../services/prediction_service.dart';
import '../../services/firestore_service.dart';
import '../../models/prediction_result.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  final String imagePath;
  const AnalysisScreen({super.key, required this.imagePath});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  double _progress = 0.0;
  int _currentStep = 0;
  Timer? _timer;

  // ── Completion state ────────────────────────────────────────────────────────
  // All three flags are instance fields to prevent race-condition double-trigger.
  bool _completionHandled = false;
  bool _apiFinished = false;
  bool _timerFinished = false;
  PredictionResult? _apiResult;
  String? _apiError;

  @override
  void initState() {
    super.initState();
    _startAnalysis();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startAnalysis() {
    const totalDuration = Duration(seconds: 4);
    const updateInterval = Duration(milliseconds: 50);
    final totalTicks =
        totalDuration.inMilliseconds / updateInterval.inMilliseconds;
    int currentTick = 0;

    // ── API call ──────────────────────────────────────────────────────────────
    PredictionService.predict(widget.imagePath).then((result) {
      _apiResult = result;
      _apiFinished = true;
      _checkCompletion();
    }).catchError((Object e) {
      _apiError = e.toString();
      _apiFinished = true;
      _checkCompletion();
    });

    // ── UI animation timer ────────────────────────────────────────────────────
    _timer = Timer.periodic(updateInterval, (timer) {
      currentTick++;
      if (mounted) {
        setState(() {
          _progress = currentTick / totalTicks;
          if (_progress > 0.25) _currentStep = 1;
          if (_progress > 0.50) _currentStep = 2;
          if (_progress > 0.75) _currentStep = 3;
          if (_progress >= 1.0) _currentStep = 4;
        });
      }

      if (_progress >= 1.0) {
        timer.cancel();
        _timerFinished = true;
        Future.delayed(
          const Duration(milliseconds: 400),
          _checkCompletion,
        );
      }
    });
  }

  /// Called from both the API callback and the timer callback.
  /// The _completionHandled flag ensures the body runs exactly once.
  void _checkCompletion() {
    if (!_timerFinished || !_apiFinished) return;
    if (_completionHandled) return;
    _completionHandled = true;

    if (!mounted) return;

    if (_apiError != null) {
      final userMessage = _parseApiError(_apiError!);
      // Pop first so the analysis screen is gone, then show the snackbar
      // on whatever screen is now on top (scan screen).
      context.pop();
      Future.microtask(() {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userMessage),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
      return;
    }

    if (_apiResult != null) {
      _saveScanResult(_apiResult!).then((_) {
        if (mounted) {
          context.pushReplacement('/results', extra: {
            'imagePath': widget.imagePath,
            'result': _apiResult,
          });
        }
      }).catchError((Object e) {
        // Firestore save failed — log and still navigate to results
        debugPrint('Firestore save error (non-fatal): $e');
        if (mounted) {
          context.pushReplacement('/results', extra: {
            'imagePath': widget.imagePath,
            'result': _apiResult,
          });
        }
      });
    }
  }

  /// Translates raw API / network exception strings into user-friendly messages.
  String _parseApiError(String rawError) {
    if (rawError.contains('BACKEND_VALIDATION_ERROR:')) {
      return rawError.split('BACKEND_VALIDATION_ERROR:').last.trim();
    }
    
    final e = rawError.toLowerCase();

    if (e.contains('401') ||
        e.contains('authentication') ||
        e.contains('unauthorized')) {
      return 'Authentication expired. Please log out and log in again.';
    }
    if (e.contains('not_fundus') || e.contains('fundus')) {
      return 'Invalid Image Detected. Please upload a clear retinal fundus image for glaucoma analysis.';
    }
    if (e.contains('poor_quality') || e.contains('quality')) {
      return 'Image Quality Insufficient. Please upload a clearer, well-lit retinal fundus image.';
    }
    if (e.contains('uncertain') || e.contains('borderline')) {
      return 'The model could not make a reliable prediction. '
          'Please try with a clearer fundus image.';
    }
    if (e.contains('422')) {
      return 'Please upload a valid retinal fundus image.';
    }
    if (e.contains('timeout')) {
      return 'Connection timed out. Please check your network and try again.';
    }
    if (e.contains('network') ||
        e.contains('socket') ||
        e.contains('connection')) {
      return 'Network error. Please check your connection and try again.';
    }
    if (e.contains('file not found') || e.contains('image file')) {
      return 'Image could not be loaded. Please select the image again.';
    }
    if (e.contains('500')) {
      return 'Server error. Please try again in a moment.';
    }
    return 'Analysis failed. Please try again.';
  }

  Future<void> _saveScanResult(PredictionResult result) async {
    // Do not persist uncertain / borderline results — no diagnosis was made.
    if (!result.showDiagnosis) return;
    final firestoreService = FirestoreService();
    await firestoreService.saveScanResult(
      predictedClass: result.predictedClass,
      confidenceScore: result.confidenceScore,
      riskStatus: result.riskStatus,
    );
  }

  @override
  Widget build(BuildContext context) {
    final langCode = ref.watch(localeProvider).languageCode;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const TopControls(),
              const SizedBox(height: 24),
              Text(
                'analyzing_image'.tr(langCode),
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 48),
              CircularPercentIndicator(
                radius: 110.0,
                lineWidth: 16.0,
                animation: false,
                percent: _progress.clamp(0.0, 1.0),
                center: Icon(
                  LucideIcons.brainCircuit,
                  size: 70,
                  color: theme.colorScheme.primary,
                ),
                circularStrokeCap: CircularStrokeCap.round,
                progressColor: theme.colorScheme.primary,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
              const SizedBox(height: 48),
              Text(
                'please_wait'.tr(langCode),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'analyzing_desc'.tr(langCode),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 48),
              _buildStepItem('step_1'.tr(langCode), 0, theme),
              _buildStepItem('step_2'.tr(langCode), 1, theme),
              _buildStepItem('step_3'.tr(langCode), 2, theme),
              _buildStepItem('step_4'.tr(langCode), 3, theme),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _progress.clamp(0.0, 1.0),
                      backgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                      minHeight: 12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${(_progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepItem(String text, int stepIndex, ThemeData theme) {
    final isCompleted = _currentStep > stepIndex;
    final isCurrent = _currentStep == stepIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isCompleted
                    ? LucideIcons.checkCircle2
                    : (isCurrent ? LucideIcons.loader : LucideIcons.circle),
                color: isCompleted
                    ? Colors.green
                    : (isCurrent ? theme.colorScheme.primary : Colors.grey),
                size: 24,
              ),
              const SizedBox(width: 16),
              Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isCurrent || isCompleted
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: isCompleted || isCurrent
                      ? theme.textTheme.bodyLarge?.color
                      : Colors.grey,
                ),
              ),
            ],
          ),
          if (isCurrent)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            )
          else if (isCompleted)
            const Icon(LucideIcons.check, size: 16, color: Colors.green),
        ],
      ),
    );
  }
}
