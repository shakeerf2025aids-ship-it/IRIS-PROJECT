import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/localization/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/top_controls.dart';
import '../../models/prediction_result.dart';
import '../../widgets/theme_toggle_button.dart';

class ResultsScreen extends ConsumerWidget {
  final String imagePath;
  final PredictionResult? result;

  const ResultsScreen({
    super.key,
    required this.imagePath,
    this.result,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final langCode = ref.watch(localeProvider).languageCode;
    final theme = Theme.of(context);

    final isGlaucoma = result?.predictedClass == 1;
    final riskColor =
        isGlaucoma ? const Color(0xFFE53935) : const Color(0xFF43A047);
    final riskTitle =
        isGlaucoma ? 'high_risk'.tr(langCode) : 'low_risk'.tr(langCode);
    final riskSubtitle =
        isGlaucoma ? 'glaucoma_suspected'.tr(langCode) : 'normal'.tr(langCode);

    final confidencePercent = result != null
        ? '${(result!.confidenceScore * 100).toStringAsFixed(1)}%'
        : '0.0%';



    return Scaffold(
      appBar: AppBar(
        title: Text(
          'analysis_results'.tr(langCode),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        actions: const [
          ThemeToggleButton(),
          SizedBox(width: 8),
          LanguageTogglePill(),
          SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Fundus image ────────────────────────────────────────────────
            if (imagePath.isNotEmpty)
              Image.file(
                File(imagePath),
                height: 280,
                width: double.infinity,
                fit: BoxFit.cover,
              )
            else
              Image.asset(
                'assets/fundus.png',
                height: 280,
                width: double.infinity,
                fit: BoxFit.cover,
              ),

            // ── Risk card ───────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: riskColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            riskTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            riskSubtitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            confidencePercent,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'risk_score'.tr(langCode),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // ── Confidence badge ──────────────────────────────────────
                  if (result != null) ...[
                    const SizedBox(height: 16),
                    _ConfidenceBadge(result: result!),
                  ],
                ],
              ),
            ),

            // ── Disclaimer banner ───────────────────────────────────────────
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    LucideIcons.alertTriangle,
                    size: 16,
                    color: Colors.amber.shade700,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      result?.disclaimer ??
                          'FOR RESEARCH AND SCREENING USE ONLY. '
                              'NOT A MEDICAL DIAGNOSIS.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Quality warning banner ──────────────────────────────────────
            if (result != null && result!.warning != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      LucideIcons.alertOctagon,
                      size: 20,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Low image quality. Results should be interpreted with caution.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Clinical action card ────────────────────────────────────────
            if (result != null && result!.confidenceAction.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      LucideIcons.stethoscope,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        result!.confidenceAction,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Key parameters ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'key_parameters'.tr(langCode),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          LucideIcons.info,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Advanced anatomical measurements such as Cup-to-Disc Ratio, Optic Disc Segmentation, and Retinal Feature Analysis are under development and will be available in a future release.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Model uncertainty row
                  if (result != null && result!.uncertainty > 0.0) ...[
                    const SizedBox(height: 4),
                    _buildParameterRow(
                      'Model Uncertainty',
                      '${(result!.uncertainty * 100).toStringAsFixed(1)}%',
                      result!.uncertainty > 0.15
                          ? Colors.orange
                          : Colors.green,
                    ),
                  ],

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/report', extra: {
            'imagePath': imagePath,
            'result': result,
          });
        },
        backgroundColor: theme.colorScheme.primary,
        icon: const Icon(LucideIcons.fileText, color: Colors.white),
        label: Text(
          'your_report'.tr(langCode),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildParameterRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Confidence Badge ──────────────────────────────────────────────────────────

class _ConfidenceBadge extends StatelessWidget {
  final PredictionResult result;
  const _ConfidenceBadge({required this.result});

  @override
  Widget build(BuildContext context) {
    final cfg = _config(result.confidenceLevel);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cfg.bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(cfg.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            result.confidenceLabel,
            style: TextStyle(
              color: cfg.textColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeCfg _config(String level) {
    switch (level) {
      case 'very_high':
        return _BadgeCfg(
          emoji: '🔴',
          bgColor: Colors.red.shade900.withValues(alpha: 0.85),
          textColor: Colors.white,
        );
      case 'high':
        return _BadgeCfg(
          emoji: '🟢',
          bgColor: Colors.green.shade800.withValues(alpha: 0.85),
          textColor: Colors.white,
        );
      case 'moderate':
        return _BadgeCfg(
          emoji: '🟠',
          bgColor: Colors.orange.shade800.withValues(alpha: 0.85),
          textColor: Colors.white,
        );
      case 'low':
        return _BadgeCfg(
          emoji: '🟡',
          bgColor: Colors.yellow.shade700.withValues(alpha: 0.9),
          textColor: Colors.black87,
        );
      case 'borderline':
        return _BadgeCfg(
          emoji: '⚠️',
          bgColor: Colors.deepOrange.shade700.withValues(alpha: 0.85),
          textColor: Colors.white,
        );
      case 'uncertain':
      default:
        return _BadgeCfg(
          emoji: '⚠️',
          bgColor: Colors.grey.shade700.withValues(alpha: 0.85),
          textColor: Colors.white,
        );
    }
  }
}

class _BadgeCfg {
  final String emoji;
  final Color bgColor;
  final Color textColor;
  const _BadgeCfg({
    required this.emoji,
    required this.bgColor,
    required this.textColor,
  });
}
