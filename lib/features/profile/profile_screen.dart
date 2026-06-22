import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../providers/locale_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoading = false;

  // ─── Logout ─────────────────────────────────────────────────────────────────

  Future<void> _handleLogout() async {
    if (!mounted) return;
    final langCode = ref.read(localeProvider).languageCode;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('logout_confirm_title'.tr(langCode)),
        content: Text('logout_confirm_message'.tr(langCode)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr(langCode)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'logout'.tr(langCode),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      await authService.logout();
      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString(), isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  // ─── Edit Profile ───────────────────────────────────────────────────────────

  Future<void> _handleEditProfile() async {
    final langCode = ref.read(localeProvider).languageCode;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final nameController = TextEditingController(
      text: user.displayName ?? '',
    );
    final formKey = GlobalKey<FormState>();

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('edit_profile'.tr(langCode)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'full_name'.tr(langCode),
              prefixIcon: const Icon(LucideIcons.user),
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'name_required'.tr(langCode);
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr(langCode)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, nameController.text.trim());
              }
            },
            child: Text('save'.tr(langCode)),
          ),
        ],
      ),
    );

    nameController.dispose();

    if (newName == null || newName.isEmpty || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      await authService.updateUserProfile(displayName: newName);
      if (mounted) {
        _showSnackBar('profile_updated_success'.tr(langCode));
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString(), isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  // ─── Change Password ────────────────────────────────────────────────────────

  Future<void> _handleChangePassword() async {
    final langCode = ref.read(localeProvider).languageCode;
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool obscureCurrent = true;
        bool obscureNew = true;
        bool obscureConfirm = true;

        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text('change_password'.tr(langCode)),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentPasswordController,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'current_password'.tr(langCode),
                        prefixIcon: const Icon(LucideIcons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent ? LucideIcons.eyeOff : LucideIcons.eye),
                          onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'current_password_required'.tr(langCode);
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'new_password'.tr(langCode),
                        prefixIcon: const Icon(LucideIcons.keyRound),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? LucideIcons.eyeOff : LucideIcons.eye),
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'new_password_required'.tr(langCode);
                        }
                        if (value.length < 6) {
                          return 'password_min_length'.tr(langCode);
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'confirm_new_password'.tr(langCode),
                        prefixIcon: const Icon(LucideIcons.keyRound),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? LucideIcons.eyeOff : LucideIcons.eye),
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'confirm_password_required'.tr(langCode);
                        }
                        if (value != newPasswordController.text) {
                          return 'passwords_do_not_match'.tr(langCode);
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('cancel'.tr(langCode)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.pop(ctx, true);
                  }
                },
                child: Text('change_password'.tr(langCode)),
              ),
            ],
          ),
        );
      },
    ) ?? false;

    if (!confirmed || !mounted) {
      currentPasswordController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      await authService.changePassword(
        currentPassword: currentPasswordController.text,
        newPassword: newPasswordController.text,
      );
      if (mounted) {
        _showSnackBar('password_changed_success'.tr(langCode));
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString(), isError: true);
      }
    } finally {
      currentPasswordController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ─── Delete Account ─────────────────────────────────────────────────────────

  Future<void> _handleDeleteAccount() async {
    final langCode = ref.read(localeProvider).languageCode;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // First confirmation dialog
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: Colors.red.shade600, size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text('delete_account'.tr(langCode))),
          ],
        ),
        content: Text('delete_account_warning'.tr(langCode)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr(langCode)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'delete_account_confirm'.tr(langCode),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ) ?? false;

    if (!firstConfirm || !mounted) return;

    // Password re-authentication dialog
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final password = await showDialog<String>(
      context: context,
      builder: (ctx) {
        bool obscure = true;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text('enter_password_to_confirm'.tr(langCode)),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: passwordController,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'password'.tr(langCode),
                  prefixIcon: const Icon(LucideIcons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? LucideIcons.eyeOff : LucideIcons.eye),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'password_required'.tr(langCode);
                  }
                  return null;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('cancel'.tr(langCode)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.pop(ctx, passwordController.text);
                  }
                },
                child: Text(
                  'delete_permanently'.tr(langCode),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );

    passwordController.dispose();

    if (password == null || password.isEmpty || !mounted) return;

    setState(() => _isLoading = true);

    try {
      // Capture userId before deletion
      final userId = user.uid;

      // Step 1: Delete all Firestore scan data
      final firestoreService = FirestoreService();
      await firestoreService.deleteAllUserScans(userId);

      // Step 2: Delete Firebase Auth account (re-authenticates internally)
      final authService = AuthService();
      await authService.deleteAccount(password);

      // Step 3: Navigate to login
      if (mounted) {
        _showSnackBar('account_deleted_success'.tr(langCode));
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString(), isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final langCode = ref.watch(localeProvider).languageCode;
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: user == null
          ? _buildNotAuthenticatedState(langCode, theme)
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildAvatarSection(user, theme, langCode),
                    const SizedBox(height: 24),
                    _buildAccountInfoCard(user, theme, langCode, isDark),
                    const SizedBox(height: 24),
                    _buildAccountActionsCard(theme, langCode, isDark),
                    const SizedBox(height: 32),
                    _buildLogoutButton(langCode),
                    const SizedBox(height: 32),
                  ],
                ),
                if (_isLoading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
    );
  }

  // ─── Not Authenticated ──────────────────────────────────────────────────────

  Widget _buildNotAuthenticatedState(String langCode, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.user, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('not_authenticated'.tr(langCode)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/login'),
            child: Text('login'.tr(langCode)),
          ),
        ],
      ),
    );
  }

  // ─── Avatar Section ─────────────────────────────────────────────────────────

  Widget _buildAvatarSection(User user, ThemeData theme, String langCode) {
    final initial = (user.displayName?.isNotEmpty == true)
        ? user.displayName!.substring(0, 1).toUpperCase()
        : (user.email?.substring(0, 1).toUpperCase() ?? 'U');

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: theme.colorScheme.primary,
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 48,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user.displayName ?? 'profile'.tr(langCode),
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              user.email ?? 'N/A',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Account Information Card ───────────────────────────────────────────────

  Widget _buildAccountInfoCard(User user, ThemeData theme, String langCode, bool isDark) {
    return Card(
      elevation: isDark ? 0 : 2,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'account_information'.tr(langCode),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              icon: LucideIcons.mail,
              label: 'email'.tr(langCode),
              value: user.email ?? 'N/A',
              theme: theme,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: LucideIcons.calendar,
              label: 'joined'.tr(langCode),
              value: _formatDate(user.metadata.creationTime),
              theme: theme,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: LucideIcons.shieldCheck,
              label: 'verified'.tr(langCode),
              value: user.emailVerified
                  ? 'yes'.tr(langCode)
                  : 'no'.tr(langCode),
              theme: theme,
              valueColor: user.emailVerified ? Colors.green : Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Account Actions Card ──────────────────────────────────────────────────

  Widget _buildAccountActionsCard(ThemeData theme, String langCode, bool isDark) {
    return Card(
      elevation: isDark ? 0 : 2,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'account_actions'.tr(langCode),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Edit Profile
            ListTile(
              leading: Icon(
                LucideIcons.edit3,
                color: theme.colorScheme.primary,
              ),
              title: Text('edit_profile'.tr(langCode)),
              trailing: const Icon(LucideIcons.chevronRight, size: 20),
              onTap: _isLoading ? null : _handleEditProfile,
            ),
            Divider(color: Colors.grey.withValues(alpha: 0.3)),

            // Change Password
            ListTile(
              leading: Icon(
                LucideIcons.lock,
                color: theme.colorScheme.primary,
              ),
              title: Text('change_password'.tr(langCode)),
              trailing: const Icon(LucideIcons.chevronRight, size: 20),
              onTap: _isLoading ? null : _handleChangePassword,
            ),
            Divider(color: Colors.grey.withValues(alpha: 0.3)),

            // Delete Account
            ListTile(
              leading: const Icon(
                LucideIcons.trash2,
                color: Colors.red,
              ),
              title: Text(
                'delete_account'.tr(langCode),
                style: const TextStyle(color: Colors.red),
              ),
              trailing: const Icon(LucideIcons.chevronRight, size: 20),
              onTap: _isLoading ? null : _handleDeleteAccount,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Logout Button ──────────────────────────────────────────────────────────

  Widget _buildLogoutButton(String langCode) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _handleLogout,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              ),
            )
          : const Icon(LucideIcons.logOut),
      label: Text(
        _isLoading
            ? 'logging_out'.tr(langCode)
            : 'logout'.tr(langCode),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ─── Info Row ───────────────────────────────────────────────────────────────

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
