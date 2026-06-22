import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/localization/app_localizations.dart';
import '../../models/prediction_result.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/firestore_provider.dart';
import '../../services/report_service.dart';


class ReportScreen extends ConsumerStatefulWidget {
  final String? imagePath;
  final PredictionResult? result;

  const ReportScreen({
    super.key,
    this.imagePath,
    this.result,
  });

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final ReportService _reportService = ReportService();
  bool _isGenerating = false;
  bool _isSharing = false;
  String? _generatedPdfPath;

  PredictionResult? get _effectiveResult {
    // If we have a result passed from navigation (e.g. fresh scan), use it.
    if (widget.result != null) return widget.result;
    
    // Otherwise, check if we have a latest scan from Firestore.
    final stats = ref.read(dashboardStatsProvider).value;
    final latest = stats?.latestScan;
    
    if (latest != null) {
      return PredictionResult(
        predictedClass: latest.predictedClass,
        confidenceScore: latest.confidenceScore,
        riskStatus: latest.riskStatus,
      );
    }
    
    return null;
  }


  Future<void> _generatePdf() async {
    final effectiveResult = _effectiveResult;
    if (effectiveResult == null) return;

    setState(() => _isGenerating = true);
    try {
      final user = ref.read(currentUserProvider);
      final langCode = ref.read(localeProvider).languageCode;
      final pdfBytes = await _reportService.generateReport(
        userName: user?.displayName ?? 'Unknown',
        userEmail: user?.email ?? 'N/A',
        result: effectiveResult,
        langCode: langCode,
        imagePath: widget.imagePath, // May be null if loaded from Firestore
      );

      final filePath = await _reportService.savePdfToTemp(pdfBytes);
      setState(() => _generatedPdfPath = filePath);

      if (mounted) {
        final langCode = ref.read(localeProvider).languageCode;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('pdf_generated'.tr(langCode)),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            action: SnackBarAction(
              label: 'open'.tr(langCode),
              textColor: Colors.white,
              onPressed: () => _openPdf(filePath),
            ),
          ),
        );
      }
    } on ReportException catch (e) {
      if (mounted) {
        final langCode = ref.read(localeProvider).languageCode;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'pdf_generation_failed'.tr(langCode)}: ${e.message}'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('unexpected_error_pdf'.tr(ref.read(localeProvider).languageCode)),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _shareReport() async {
    final effectiveResult = _effectiveResult;
    if (effectiveResult == null) return;

    setState(() => _isSharing = true);
    try {
      // Generate PDF first if not already generated
      String pdfPath;
      if (_generatedPdfPath != null) {
        pdfPath = _generatedPdfPath!;
      } else {
        final user = ref.read(currentUserProvider);
        final langCode = ref.read(localeProvider).languageCode;
        final pdfBytes = await _reportService.generateReport(
          userName: user?.displayName ?? 'Unknown',
          userEmail: user?.email ?? 'N/A',
          result: effectiveResult,
          langCode: langCode,
          imagePath: widget.imagePath,
        );
        pdfPath = await _reportService.savePdfToTemp(pdfBytes);
        setState(() => _generatedPdfPath = pdfPath);
      }

      await _reportService.sharePdf(pdfPath);
    } on ReportException catch (e) {
      if (mounted) {
        final langCode = ref.read(localeProvider).languageCode;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'share_failed'.tr(langCode)}: ${e.message}'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('unexpected_error_share'.tr(ref.read(localeProvider).languageCode)),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _openPdf(String filePath) async {
    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'could_not_open_file'.tr(ref.read(localeProvider).languageCode)} ${result.message}'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Need to watch dashboardStatsProvider so that _effectiveResult updates 
    // when Firestore syncs the latest scan down.
    ref.watch(dashboardStatsProvider);
    
    final langCode = ref.watch(localeProvider).languageCode;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);

    final effectiveResult = _effectiveResult;
    final hasResult = effectiveResult != null;

    // Dynamic data from PredictionResult
    final isGlaucoma = effectiveResult?.predictedClass == 1;
    final confidenceScore = effectiveResult?.confidenceScore ?? 0.0;
    final confidencePercent = (confidenceScore * 100).toStringAsFixed(1);
    final riskStatus = effectiveResult?.riskStatus ?? '';
    final userName = user?.displayName ?? 'Unknown';
    final userEmail = user?.email ?? 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: Text('your_report'.tr(langCode), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.share),
            onPressed: hasResult ? _shareReport : null,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── No Data Banner ──
            if (!hasResult) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.amber.shade900.withValues(alpha: 0.2) : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade300, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.alertTriangle, color: Colors.amber.shade700, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'no_scan_data'.tr(langCode),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.amber.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'scan_first_to_generate'.tr(langCode),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── Patient Info Card ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.05)),
                boxShadow: isDark ? [] : [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(LucideIcons.user, size: 32, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('patient_name'.tr(langCode), userName, theme),
                        const SizedBox(height: 12),
                        _buildInfoRow('email'.tr(langCode), userEmail, theme),
                        const SizedBox(height: 12),
                        // Note: ideally we'd show the timestamp of the scan from Firestore.
                        // For simplicity, we keep current date for "Report Date".
                        _buildInfoRow('scan_date'.tr(langCode), _formatCurrentDate(), theme),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            if (hasResult) ...[
              Text('result'.tr(langCode), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 12),
            
            // ── Risk Card ──
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isGlaucoma
                      ? Colors.redAccent.withValues(alpha: 0.2)
                      : Colors.green.withValues(alpha: 0.2),
                  width: 2,
                ),
                boxShadow: isDark ? [] : [
                  BoxShadow(
                    color: (isGlaucoma ? Colors.redAccent : Colors.green).withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isGlaucoma ? 'high_risk'.tr(langCode) : 'low_risk'.tr(langCode),
                        style: TextStyle(
                          color: isGlaucoma ? Colors.redAccent : Colors.green,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isGlaucoma ? 'glaucoma_suspected'.tr(langCode) : 'normal'.tr(langCode),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        riskStatus,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: confidenceScore,
                          strokeWidth: 8,
                          backgroundColor: (isGlaucoma ? Colors.redAccent : Colors.green).withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(isGlaucoma ? Colors.redAccent : Colors.green),
                        ),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$confidencePercent%',
                                style: TextStyle(
                                  color: isGlaucoma ? Colors.redAccent : Colors.green,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'risk_score'.tr(langCode),
                                style: TextStyle(
                                  color: isGlaucoma ? Colors.redAccent : Colors.green,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            Text('recommendation'.tr(langCode), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 12),
            
            // ── Recommendation Card ──
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2032) : const Color(0xFFF9FAFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isGlaucoma
                          ? 'recommendation_desc'.tr(langCode)
                          : 'normal_recommendation_desc'.tr(langCode),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.5),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Image.asset(
                    'assets/doctor.png',
                    height: 80,
                    width: 80,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(LucideIcons.stethoscope, size: 60, color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),

            // ── Disclaimer ──
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.amber.shade900.withValues(alpha: 0.1) : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200.withValues(alpha: 0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.alertCircle, size: 18, color: Colors.amber.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'report_disclaimer'.tr(langCode),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.amber.shade800,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ],
            
            const SizedBox(height: 48),
            
            // ── Action Buttons ──
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: hasResult
                        ? (_isGenerating ? null : _generatePdf)
                        : null,
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(LucideIcons.download, size: 20),
                    label: Text(
                      _isGenerating
                          ? 'generating_pdf'.tr(langCode)
                          : 'download_pdf'.tr(langCode),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      side: BorderSide(
                        color: hasResult
                            ? theme.colorScheme.primary
                            : Colors.grey,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      foregroundColor: hasResult
                          ? theme.colorScheme.primary
                          : Colors.grey,
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: hasResult
                        ? (_isSharing ? null : _shareReport)
                        : null,
                    icon: _isSharing
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : const Icon(LucideIcons.share2, size: 20),
                    label: Text(
                      _isSharing
                          ? 'sharing_report'.tr(langCode)
                          : 'share_report'.tr(langCode),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _formatCurrentDate() {
    final now = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final period = now.hour >= 12 ? 'PM' : 'AM';
    final minute = now.minute.toString().padLeft(2, '0');
    return '${now.day} ${months[now.month - 1]} ${now.year} • $hour:$minute $period';
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
