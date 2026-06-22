import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/localization/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/top_controls.dart';
import '../../widgets/theme_toggle_button.dart';

class NewScanScreen extends ConsumerStatefulWidget {
  const NewScanScreen({super.key});

  @override
  ConsumerState<NewScanScreen> createState() => _NewScanScreenState();
}

class _NewScanScreenState extends ConsumerState<NewScanScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _selectedImagePath;

  /// Guards against concurrent picker invocations (e.g. double-tap).
  bool _isPickerActive = false;

  Future<void> _pickImage(ImageSource source) async {
    if (_isPickerActive) return;
    _isPickerActive = true;

    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
      );

      if (!mounted) return;

      // Null means the user cancelled — not an error.
      if (picked == null) return;

      // Validate the file is accessible and non-empty.
      final file = File(picked.path);
      if (!await file.exists()) {
        _showError('Image could not be loaded. Please try again.');
        return;
      }
      final size = await file.length();
      if (size == 0) {
        _showError('Selected image is empty. Please choose a different image.');
        return;
      }

      debugPrint('Original image path: ${picked.path}');
      debugPrint('Original image size: $size bytes');

      if (mounted) {
        setState(() => _selectedImagePath = picked.path);
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();

      // User deliberately cancelled — no error shown.
      if (msg.contains('cancel') || msg.contains('user_cancel')) return;

      if (msg.contains('permission') || msg.contains('denied')) {
        _showError(
          'Camera or gallery access was denied.\n'
          'Please enable the permission in your device settings.',
        );
      } else {
        _showError('Unable to open image. Please try again.');
      }
    } finally {
      _isPickerActive = false;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final langCode = ref.watch(localeProvider).languageCode;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Text(
                'start_new_scan'.tr(langCode),
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'capture_upload_desc'.tr(langCode),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 48),

              // Image preview or placeholder
              if (_selectedImagePath == null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/scanner.png',
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 320),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.file(
                      File(_selectedImagePath!),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

              const SizedBox(height: 40),

              if (_selectedImagePath == null) ...[
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(LucideIcons.camera, size: 20),
                  label: Text('capture_image'.tr(langCode)),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    side: BorderSide(
                      color: isDark ? Colors.white24 : Colors.black12,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    foregroundColor: theme.textTheme.bodyLarge?.color,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: Icon(
                    LucideIcons.imagePlus,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  label: Text('upload_image'.tr(langCode)),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: () {
                    context.push('/analysis', extra: _selectedImagePath);
                  },
                  icon: const Icon(LucideIcons.brainCircuit, size: 20),
                  label: Text('analyze_image'.tr(langCode)),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _selectedImagePath = null);
                  },
                  icon: const Icon(
                    LucideIcons.refreshCcw,
                    size: 16,
                    color: Colors.grey,
                  ),
                  label: Text(
                    'reselect_image'.tr(langCode),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],

              const SizedBox(height: 40),

              // Tips card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E2032)
                      : const Color(0xFFF9FAFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'tips_for_best_result'.tr(langCode),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildTipItem('tip_1'.tr(langCode), theme),
                          _buildTipItem('tip_2'.tr(langCode), theme),
                          _buildTipItem('tip_3'.tr(langCode), theme),
                        ],
                      ),
                    ),
                    Icon(
                      LucideIcons.eye,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipItem(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Icon(
            LucideIcons.checkCircle2,
            size: 14,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
