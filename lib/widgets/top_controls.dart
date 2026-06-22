import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/locale_provider.dart';
import '../widgets/theme_toggle_button.dart';

class TopControls extends ConsumerWidget {
  const TopControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ThemeToggleButton(),
          LanguageTogglePill(),
        ],
      ),
    );
  }
}



class LanguageTogglePill extends ConsumerWidget {
  const LanguageTogglePill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.globe, size: 14),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: locale.languageCode,
              isDense: true,
              icon: const Icon(LucideIcons.chevronDown, size: 14),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('EN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                DropdownMenuItem(value: 'ta', child: Text('TA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              ],
              onChanged: (val) {
                if (val != null) {
                  ref.read(localeProvider.notifier).setLocale(Locale(val));
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
