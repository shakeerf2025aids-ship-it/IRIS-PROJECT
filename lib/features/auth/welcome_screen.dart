import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/localization/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/iris_logo.dart';
import '../../widgets/top_controls.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final langCode = ref.watch(localeProvider).languageCode;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopControls(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    const Hero(
                      tag: 'app_logo',
                      child: IrisLogo(size: 160),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'app_title'.tr(langCode),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'app_subtitle'.tr(langCode),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'tagline'.tr(langCode),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    
                    // Feature Cards Grid
                    Row(
                      children: [
                        Expanded(child: _FeatureCard(icon: LucideIcons.cpu, title: 'ai_powered_analysis'.tr(langCode))),
                        const SizedBox(width: 12),
                        Expanded(child: _FeatureCard(icon: LucideIcons.target, title: 'accurate_risk'.tr(langCode))),
                        const SizedBox(width: 12),
                        Expanded(child: _FeatureCard(icon: LucideIcons.lock, title: 'secure_data'.tr(langCode))),
                        const SizedBox(width: 12),
                        Expanded(child: _FeatureCard(icon: LucideIcons.zap, title: 'fast_easy'.tr(langCode))),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: () => context.push('/login'),
                    child: Text('get_started'.tr(langCode)),
                  ),
                  const SizedBox(height: 24),
                  InkWell(
                    onTap: () => context.push('/login'),
                    child: Text.rich(
                      TextSpan(
                        text: '${'already_have_account'.tr(langCode)} ',
                        style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontWeight: FontWeight.w500),
                        children: [
                          TextSpan(
                            text: 'login'.tr(langCode),
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;

  const _FeatureCard({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2032) : const Color(0xFFF9FAFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 24),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
