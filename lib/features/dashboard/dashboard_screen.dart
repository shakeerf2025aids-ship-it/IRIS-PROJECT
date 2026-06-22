import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/localization/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../../providers/firestore_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/top_controls.dart';
import '../history/history_screen.dart';
import '../profile/profile_screen.dart';
import '../report/report_screen.dart';
import '../../widgets/theme_toggle_button.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final langCode = ref.watch(localeProvider).languageCode;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final List<Widget> screens = [
      _buildDashboardContent(context, ref, langCode, theme, isDark),
      const HistoryScreen(),
      const ReportScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(LucideIcons.menu), onPressed: () {}),
        actions: [
          const ThemeToggleButton(),
          const SizedBox(width: 8),
          const LanguageTogglePill(),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(LucideIcons.bell), onPressed: () {}),
        ],
      ),
      body: screens[_currentIndex],
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.primary,
        onPressed: () => context.push('/scan'),
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(LucideIcons.scanLine, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 20,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: [
          BottomNavigationBarItem(icon: const Icon(LucideIcons.home), label: 'home'.tr(langCode)),
          BottomNavigationBarItem(icon: const Icon(LucideIcons.history), label: 'history'.tr(langCode)),
          BottomNavigationBarItem(icon: const Icon(LucideIcons.fileText), label: 'reports'.tr(langCode)),
          BottomNavigationBarItem(icon: const Icon(LucideIcons.user), label: 'profile'.tr(langCode)),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    WidgetRef ref,
    String langCode,
    ThemeData theme,
    bool isDark,
  ) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final user = ref.watch(currentUserProvider);
    final greeting = user?.displayName != null
        ? '${'hello'.tr(langCode)}, ${user!.displayName} \uD83D\uDC4B'
        : 'hello_user'.tr(langCode);

    return statsAsync.when(
      loading: () => _buildLoadingState(theme, langCode, greeting),
      error: (error, _) => _buildErrorState(theme, langCode, error, greeting),
      data: (stats) => _buildDataState(
        context, ref, langCode, theme, isDark, stats, greeting,
      ),
    );
  }

  // ─── Loading State ──────────────────────────────────────────────────────────

  Widget _buildLoadingState(ThemeData theme, String langCode, String greeting) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'take_care_eyes'.tr(langCode),
            style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 48),
          Center(
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'loading_dashboard'.tr(langCode),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Error State ────────────────────────────────────────────────────────────

  Widget _buildErrorState(
    ThemeData theme,
    String langCode,
    Object error,
    String greeting,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'take_care_eyes'.tr(langCode),
            style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 48),
          Center(
            child: Column(
              children: [
                Icon(LucideIcons.alertTriangle, size: 48, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  'error_loading_dashboard'.tr(langCode),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(userScansProvider),
                  icon: const Icon(LucideIcons.refreshCw, size: 16),
                  label: Text('retry'.tr(langCode)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Data State (main content) ──────────────────────────────────────────────

  Widget _buildDataState(
    BuildContext context,
    WidgetRef ref,
    String langCode,
    ThemeData theme,
    bool isDark,
    DashboardStats stats,
    String greeting,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userScansProvider);
        await ref.read(userScansProvider.future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'take_care_eyes'.tr(langCode),
              style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),

            // Risk Status Card — dynamic based on real scan distribution
            _buildRiskStatusCard(theme, langCode, stats),
            const SizedBox(height: 24),

            // Stats Grid — real Firestore counts
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    theme, isDark, LucideIcons.camera,
                    'total_scans'.tr(langCode),
                    stats.totalScans.toString(),
                    const Color(0xFF382DEB),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    theme, isDark, LucideIcons.shieldCheck,
                    'normal'.tr(langCode),
                    stats.normalCount.toString(),
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    theme, isDark, LucideIcons.alertTriangle,
                    'high_risk'.tr(langCode),
                    stats.highRiskCount.toString(),
                    Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    theme, isDark, LucideIcons.eyeOff,
                    'glaucoma'.tr(langCode),
                    stats.glaucomaCount.toString(),
                    Colors.red,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Last Scan section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('last_scan'.tr(langCode), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                TextButton(
                  onPressed: () {
                    setState(() => _currentIndex = 1);
                  },
                  child: Text('view_all'.tr(langCode), style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),

            // Last Scan Card — real data or empty state
            if (stats.latestScan != null)
              _buildLastScanCard(theme, isDark, langCode, stats.latestScan!)
            else
              _buildEmptyScanCard(theme, isDark, langCode),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ─── Risk Status Card ───────────────────────────────────────────────────────

  Widget _buildRiskStatusCard(ThemeData theme, String langCode, DashboardStats stats) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF382DEB), Color(0xFF6A4CFF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            bottom: -20,
            child: Opacity(
              opacity: 0.9,
              child: Image.asset('assets/new_logo.jpg', fit: BoxFit.contain, width: 150),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'overall_risk_status'.tr(langCode),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  stats.overallRiskKey.tr(langCode),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Last Scan Card (real data) ─────────────────────────────────────────────

  Widget _buildLastScanCard(
    ThemeData theme,
    bool isDark,
    String langCode,
    ScanResult scan,
  ) {
    final isGlaucoma = scan.riskStatus == 'Glaucoma';
    final riskColor = isGlaucoma ? Colors.redAccent : Colors.green;
    final riskLabel = isGlaucoma ? 'high_risk'.tr(langCode) : 'low_risk'.tr(langCode);
    final confidenceText = '${(scan.confidenceScore * 100).toStringAsFixed(0)}%';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.05)),
        boxShadow: isDark
            ? []
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: riskColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isGlaucoma ? LucideIcons.alertTriangle : LucideIcons.shieldCheck,
                color: riskColor,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatTimestamp(scan.timestamp),
                  style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${'risk'.tr(langCode)}: ',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Flexible(
                      child: Text(
                        riskLabel,
                        style: TextStyle(color: riskColor, fontWeight: FontWeight.w800, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            confidenceText,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: riskColor),
          ),
        ],
      ),
    );
  }

  // ─── Empty Scan Card ────────────────────────────────────────────────────────

  Widget _buildEmptyScanCard(ThemeData theme, bool isDark, String langCode) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.05)),
        boxShadow: isDark
            ? []
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Icon(LucideIcons.scanLine, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'no_scans_yet'.tr(langCode),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'start_first_scan'.tr(langCode),
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => context.push('/scan'),
            icon: const Icon(LucideIcons.camera, size: 16),
            label: Text('start_new_scan'.tr(langCode)),
          ),
        ],
      ),
    );
  }

  // ─── Stat Card ──────────────────────────────────────────────────────────────

  Widget _buildStatCard(ThemeData theme, bool isDark, IconData icon, String title, String value, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.05)),
        boxShadow: isDark
            ? []
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _formatTimestamp(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final month = months[dt.month - 1];
    final day = dt.day;
    final year = dt.year;
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$day $month $year \u2022 $hour:$minute $period';
  }
}
