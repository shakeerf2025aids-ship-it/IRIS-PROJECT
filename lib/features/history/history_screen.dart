import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/localization/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../../providers/firestore_provider.dart';
import '../../services/firestore_service.dart';
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final langCode = ref.watch(localeProvider).languageCode;
    final theme = Theme.of(context);
    final scansAsyncValue = ref.watch(userScansProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: Text('scan_history'.tr(langCode)),
        actions: const [
          SizedBox(width: 16),
        ],
      ),
      body: scansAsyncValue.when(
        // Loading state
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        // Error state
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.alertCircle,
                size: 64,
                color: Colors.red.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 16),
              Text(
                'error_loading_history'.tr(langCode),
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // ignore: unused_result
                  ref.refresh(userScansProvider);
                },
                child: Text('retry'.tr(langCode)),
              ),
            ],
          ),
        ),
        // Data state
        data: (scans) {
          // Empty state
          if (scans.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.inbox,
                    size: 64,
                    color: Colors.grey.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'no_scan_history'.tr(langCode),
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'start_scanning_to_build_history'.tr(langCode),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.go('/scan'),
                    child: Text('start_new_scan'.tr(langCode)),
                  ),
                ],
              ),
            );
          }

          // List of scans
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary card
                _SummaryCard(
                  scans: scans,
                  langCode: langCode,
                  theme: theme,
                ),
                const SizedBox(height: 24),
                // Scan history title
                Text(
                  'recent_scans'.tr(langCode),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                // Scan list
                ...scans.map((scan) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ScanCard(
                      scan: scan,
                      langCode: langCode,
                      theme: theme,
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final List<ScanResult> scans;
  final String langCode;
  final ThemeData theme;

  const _SummaryCard({
    required this.scans,
    required this.langCode,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate statistics
    final glaucomaCount = scans.where((s) => s.riskStatus == 'Glaucoma').length;
    final normalCount = scans.where((s) => s.riskStatus == 'Normal').length;
    final avgConfidence = scans.fold<double>(
          0,
          (prev, scan) => prev + scan.confidenceScore,
        ) /
        scans.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'scan_statistics'.tr(langCode),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'total_scans'.tr(langCode),
                  value: scans.length.toString(),
                  color: Colors.blue,
                  theme: theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatItem(
                  label: 'glaucoma'.tr(langCode),
                  value: glaucomaCount.toString(),
                  color: Colors.red,
                  theme: theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatItem(
                  label: 'normal'.tr(langCode),
                  value: normalCount.toString(),
                  color: Colors.green,
                  theme: theme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                LucideIcons.target,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'avg_confidence'.tr(langCode),
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                '${(avgConfidence * 100).toStringAsFixed(2)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final ThemeData theme;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ScanCard extends StatelessWidget {
  final ScanResult scan;
  final String langCode;
  final ThemeData theme;

  const _ScanCard({
    required this.scan,
    required this.langCode,
    required this.theme,
  });

  Color _getRiskColor() {
    switch (scan.riskStatus.toLowerCase()) {
      case 'glaucoma':
        return Colors.red;
      case 'normal':
        return Colors.green;
      case 'suspect':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getRiskIcon() {
    switch (scan.riskStatus.toLowerCase()) {
      case 'glaucoma':
        return LucideIcons.alertCircle;
      case 'normal':
        return LucideIcons.checkCircle;
      case 'suspect':
        return LucideIcons.alertTriangle;
      default:
        return LucideIcons.helpCircle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final riskColor = _getRiskColor();
    final riskIcon = _getRiskIcon();
    final formattedDate = DateFormat('MMM dd, yyyy').format(scan.timestamp);
    final formattedTime = DateFormat('hh:mm a').format(scan.timestamp);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Risk status and date
          Row(
            children: [
              Icon(riskIcon, size: 20, color: riskColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scan.riskStatus,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: riskColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formattedTime,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Confidence score row
          Row(
            children: [
              Icon(
                LucideIcons.target,
                size: 16,
                color: Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                'confidence_score'.tr(langCode),
                style: theme.textTheme.labelSmall,
              ),
              const Spacer(),
              Text(
                '${(scan.confidenceScore * 100).toStringAsFixed(2)}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Confidence bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: scan.confidenceScore,
              minHeight: 6,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                _getConfidenceColor(scan.confidenceScore),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Scan ID (small)
          Text(
            'ID: ${scan.id.substring(0, 12)}...',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.grey.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.orange;
    return Colors.red;
  }
}
