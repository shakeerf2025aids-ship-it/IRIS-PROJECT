import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/firestore_service.dart';

/// Aggregated dashboard statistics computed from real Firestore scan data.
class DashboardStats {
  final int totalScans;
  final int normalCount;
  final int glaucomaCount;
  final int highRiskCount;
  final ScanResult? latestScan;

  const DashboardStats({
    required this.totalScans,
    required this.normalCount,
    required this.glaucomaCount,
    required this.highRiskCount,
    this.latestScan,
  });

  /// Determine the overall risk status from scan history.
  /// Returns 'high_risk' if majority are Glaucoma,
  /// 'moderate_risk' if any Glaucoma exists,
  /// 'low_risk' if all are Normal,
  /// 'no_data' if no scans exist.
  String get overallRiskKey {
    if (totalScans == 0) return 'no_data';
    if (glaucomaCount == 0) return 'low_risk';
    if (glaucomaCount > normalCount) return 'high_risk';
    return 'moderate_risk';
  }

  static const DashboardStats empty = DashboardStats(
    totalScans: 0,
    normalCount: 0,
    glaucomaCount: 0,
    highRiskCount: 0,
  );
}

// Firestore service provider
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

// User scans stream provider - real-time updates
final userScansProvider = StreamProvider<List<ScanResult>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getUserScansStream();
});

// Dashboard stats derived from the scans stream — auto-updates in real-time.
// No additional Firestore reads: all counts are computed client-side from the
// same stream that powers the History screen.
final dashboardStatsProvider = Provider<AsyncValue<DashboardStats>>((ref) {
  final scansAsync = ref.watch(userScansProvider);

  return scansAsync.whenData((scans) {
    final totalScans = scans.length;
    final normalCount =
        scans.where((s) => s.riskStatus == 'Normal').length;
    final glaucomaCount =
        scans.where((s) => s.riskStatus == 'Glaucoma').length;
    final highRiskCount = glaucomaCount;
    final latestScan = scans.isNotEmpty ? scans.first : null;

    return DashboardStats(
      totalScans: totalScans,
      normalCount: normalCount,
      glaucomaCount: glaucomaCount,
      highRiskCount: highRiskCount,
      latestScan: latestScan,
    );
  });
});

// Scan count provider
final scanCountProvider = FutureProvider<int>((ref) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getScanCount();
});

// Average confidence score provider
final averageConfidenceProvider = FutureProvider<double>((ref) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getAverageConfidenceScore();
});

// Single scan provider
final singleScanProvider =
    FutureProvider.family<ScanResult, String>((ref, scanId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getScanById(scanId);
});

// Scans by risk status provider
final scansByRiskStatusProvider =
    StreamProvider.family<List<ScanResult>, String>(
  (ref, riskStatus) {
    final firestoreService = ref.watch(firestoreServiceProvider);
    return firestoreService.getScansByRiskStatus(riskStatus);
  },
);
