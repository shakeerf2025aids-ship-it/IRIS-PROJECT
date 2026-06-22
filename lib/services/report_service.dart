import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../models/prediction_result.dart';
import '../core/localization/app_localizations.dart';

/// Exception for report generation errors
class ReportException implements Exception {
  final String message;
  final String code;

  ReportException({required this.message, required this.code});

  @override
  String toString() => message;
}

class ReportService {
  ReportService._();
  static final ReportService _instance = ReportService._();
  factory ReportService() => _instance;

  // Store the last generated PDF path for re-sharing
  String? _lastGeneratedPdfPath;
  String? get lastGeneratedPdfPath => _lastGeneratedPdfPath;

  /// Generate a professional PDF report
  ///
  /// [userName] - Patient / user display name
  /// [userEmail] - Patient / user email
  /// [result] - The prediction result (must not be null)
  /// [imagePath] - Optional path to the retinal fundus image
  ///
  /// Returns the bytes of the generated PDF document.
  Future<Uint8List> generateReport({
    required String userName,
    required String userEmail,
    required PredictionResult result,
    required String langCode,
    String? imagePath,
  }) async {
    try {
      final pdf = pw.Document();

      // Try to load the retinal image if available
      pw.ImageProvider? retinaImage;
      if (imagePath != null && imagePath.isNotEmpty) {
        try {
          final imageFile = File(imagePath);
          if (await imageFile.exists()) {
            final imageBytes = await imageFile.readAsBytes();
            retinaImage = pw.MemoryImage(imageBytes);
          }
        } catch (_) {
          // Image loading failed — continue without it
        }
      }

      final isGlaucoma = result.predictedClass == 1;
      final confidencePercent =
          (result.confidenceScore * 100).toStringAsFixed(1);
      final reportDate = DateFormat('dd MMM yyyy • hh:mm a').format(DateTime.now());

      // Colors
      final tealColor = PdfColor.fromHex('#0D9488');
      final redColor = PdfColor.fromHex('#E53935');
      final greenColor = PdfColor.fromHex('#43A047');
      final riskColor = isGlaucoma ? redColor : greenColor;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (context) => _buildHeader(tealColor, langCode),
          footer: (context) => _buildFooter(langCode),
          build: (context) => [
            // ── Patient Information ──
            pw.SizedBox(height: 20),
            _buildSectionTitle('patient_information'.tr(langCode), tealColor),
            pw.SizedBox(height: 10),
            _buildPatientInfoTable(userName, userEmail, reportDate, langCode),

            // ── Retinal Image ──
            if (retinaImage != null) ...[
              pw.SizedBox(height: 24),
              _buildSectionTitle('retinal_fundus_image'.tr(langCode), tealColor),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.ClipRRect(
                  horizontalRadius: 8,
                  verticalRadius: 8,
                  child: pw.Image(
                    retinaImage,
                    width: 240,
                    height: 180,
                    fit: pw.BoxFit.cover,
                  ),
                ),
              ),
            ],

            // ── Scan Results ──
            pw.SizedBox(height: 24),
            _buildSectionTitle('scan_results'.tr(langCode), tealColor),
            pw.SizedBox(height: 10),
            _buildResultsCard(result, riskColor, confidencePercent, isGlaucoma, langCode),

            // ── Recommendation ──
            pw.SizedBox(height: 24),
            _buildSectionTitle('recommendation'.tr(langCode), tealColor),
            pw.SizedBox(height: 10),
            _buildRecommendation(isGlaucoma, tealColor, langCode),

            // ── Disclaimer ──
            pw.SizedBox(height: 32),
            _buildDisclaimer(langCode),
          ],
        ),
      );

      return pdf.save();
    } catch (e) {
      throw ReportException(
        message: 'Failed to generate PDF report: $e',
        code: 'pdf_generation_failed',
      );
    }
  }

  /// Save the PDF bytes to a temporary file and return the file path.
  Future<String> savePdfToTemp(Uint8List pdfBytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${tempDir.path}/iris_report_$timestamp.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);
      _lastGeneratedPdfPath = filePath;
      return filePath;
    } catch (e) {
      throw ReportException(
        message: 'Failed to save PDF: $e',
        code: 'pdf_save_failed',
      );
    }
  }

  /// Share the PDF file using the native share dialog.
  Future<void> sharePdf(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw ReportException(
          message: 'PDF file not found. Please generate the report first.',
          code: 'file_not_found',
        );
      }

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'IRIS Eye Screening Report',
        text: 'Please find attached the IRIS eye screening report.',
      );
    } catch (e) {
      if (e is ReportException) rethrow;
      throw ReportException(
        message: 'Failed to share report: $e',
        code: 'share_failed',
      );
    }
  }

  // ─────────────────────────────────────────────
  //  PDF Building Helpers
  // ─────────────────────────────────────────────

  pw.Widget _buildHeader(PdfColor accentColor, String langCode) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Accent bar
            pw.Container(
              width: 6,
              height: 40,
              decoration: pw.BoxDecoration(
                color: accentColor,
                borderRadius: pw.BorderRadius.circular(3),
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'IRIS',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                pw.Text(
                  'eye_screening_report'.tr(langCode),
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.Spacer(),
            pw.Text(
              'ai_powered_glaucoma_screening'.tr(langCode),
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey500,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.grey300, thickness: 1),
      ],
    );
  }

  pw.Widget _buildFooter(String langCode) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300, thickness: 0.5),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'glaucoma_screening_platform'.tr(langCode),
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
            pw.Text(
              'confidential'.tr(langCode),
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey500,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildSectionTitle(String title, PdfColor accentColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: pw.BoxDecoration(
        color: accentColor,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  pw.Widget _buildPatientInfoTable(
    String name,
    String email,
    String reportDate,
    String langCode,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5),
        1: const pw.FlexColumnWidth(3),
      },
      children: [
        _tableRow('patient_name'.tr(langCode), name),
        _tableRow('email'.tr(langCode), email),
        _tableRow('scan_date'.tr(langCode), reportDate),
      ],
    );
  }

  pw.TableRow _tableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          color: PdfColors.grey100,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildResultsCard(
    PredictionResult result,
    PdfColor riskColor,
    String confidencePercent,
    bool isGlaucoma,
    String langCode,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: riskColor, width: 1.5),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(1.5),
          1: const pw.FlexColumnWidth(3),
        },
        children: [
          pw.TableRow(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                color: PdfColors.grey100,
                child: pw.Text(
                  'risk'.tr(langCode),
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  isGlaucoma ? 'high_risk'.tr(langCode) : 'low_risk'.tr(langCode),
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: riskColor,
                  ),
                ),
              ),
            ],
          ),
          _tableRow('confidence_score'.tr(langCode), '$confidencePercent%'),
          _tableRow(
            'predicted_class'.tr(langCode),
            isGlaucoma ? 'glaucoma_suspected'.tr(langCode) : 'normal'.tr(langCode),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildRecommendation(bool isGlaucoma, PdfColor tealColor, String langCode) {
    final String recommendation = isGlaucoma
        ? 'recommendation_desc'.tr(langCode)
        : 'normal_recommendation_desc'.tr(langCode);

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F0FDFA'),
        border: pw.Border.all(color: tealColor, width: 0.5),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('💡  ', style: const pw.TextStyle(fontSize: 14)),
          pw.Expanded(
            child: pw.Text(
              recommendation,
              style: pw.TextStyle(
                fontSize: 10.5,
                lineSpacing: 4,
                color: PdfColors.grey800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildDisclaimer(String langCode) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.amber50,
        border: pw.Border.all(color: PdfColors.amber200, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('⚠  ', style: const pw.TextStyle(fontSize: 12)),
          pw.Expanded(
            child: pw.Text(
              'report_disclaimer'.tr(langCode),
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey700,
                lineSpacing: 3,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
