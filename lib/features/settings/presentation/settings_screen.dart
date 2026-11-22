import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import 'widgets/experience_settings_section.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../core/widgets/person_avatar.dart';
import '../../../../core/widgets/screen_header.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../../data/repositories/in_memory_app_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _upiController;
  bool _isEditingProfile = false;
  String? _upiError;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(appRepositoryProvider);
    final user = repo.currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _upiController = TextEditingController(text: user?.upiId ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  bool _validateUpi(String value) {
    if (value.trim().isEmpty) return true; // Optional
    final upiRegex = RegExp(r'^[\w\.\-]+@[\w\-]+$');
    return upiRegex.hasMatch(value.trim());
  }

  void _saveProfile() {
    final upi = _upiController.text.trim();
    if (upi.isNotEmpty && !_validateUpi(upi)) {
      setState(() {
        _upiError = 'Invalid format (e.g. name@bank)';
      });
      return;
    }

    setState(() {
      _upiError = null;
      _isEditingProfile = false;
    });

    ref.read(appStateProvider.notifier).updateCurrentUser(
          name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
          upiId: upi.isEmpty ? null : upi,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(upi.isNotEmpty ? 'UPI ID saved' : 'Profile updated'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _exportJsonBackup() {
    final jsonStr = ref.read(appStateProvider.notifier).exportLedgerJson();
    Clipboard.setData(ClipboardData(text: jsonStr));

    final theme = context.settliv;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Row(
          children: [
            Icon(Icons.file_download_outlined, color: theme.navy),
            const SizedBox(width: 8),
            Text('JSON Backup', style: TextStyle(color: theme.ink, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ledger backup has been copied to your clipboard. You can paste it into a file or save it securely.',
              style: TextStyle(color: theme.muted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.raised,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.hairline),
              ),
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Text(
                  jsonStr,
                  style: TextStyle(
                    color: theme.ink,
                    fontFamily: 'monospace',
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonStr));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied backup again')),
              );
            },
            child: Text('Copy again', style: TextStyle(color: theme.navy)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: theme.navy),
            child: const Text('Done'),
          ),
        ],
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ledger JSON backup copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _exportExpensesCsv() {
    final csvStr = ref.read(appStateProvider.notifier).exportExpensesCsv();
    Clipboard.setData(ClipboardData(text: csvStr));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Expenses CSV exported & copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openRestoreDialog() {
    final theme = context.settliv;
    final restoreController = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: theme.surface,
          title: Row(
            children: [
              Icon(Icons.file_upload_outlined, color: theme.navy),
              const SizedBox(width: 8),
              Text('Restore from Backup', style: TextStyle(color: theme.ink, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste the JSON backup string below to restore all groups, expenses, and balances.',
                style: TextStyle(color: theme.muted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: restoreController,
                maxLines: 6,
                style: TextStyle(
                  color: theme.ink,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  hintText: 'Paste JSON backup here...',
                  hintStyle: TextStyle(color: theme.muted, fontSize: 12),
                  filled: true,
                  fillColor: theme.raised,
                  errorText: errorText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.hairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.hairline),
                  ),
                ),
                onChanged: (_) {
                  if (errorText != null) setDialogState(() => errorText = null);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: theme.muted)),
            ),
            FilledButton(
              onPressed: () {
                final text = restoreController.text.trim();
                if (text.isEmpty) {
                  setDialogState(() => errorText = 'Please paste backup JSON');
                  return;
                }
                final ok = ref.read(appStateProvider.notifier).restoreFromJson(text);
                if (ok) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ledger successfully restored from backup!'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                } else {
                  setDialogState(() => errorText = 'Invalid backup format or corrupt schema');
                }
              },
              style: FilledButton.styleFrom(backgroundColor: theme.navy),
              child: const Text('Restore'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmStartFresh(BuildContext context) {
    final theme = context.settliv;
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('Start fresh?', style: TextStyle(color: theme.ink)),
        content: Text(
          'This will clear all demo groups and expenses, giving you a completely clean, empty app.',
          style: TextStyle(color: theme.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: theme.muted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(appStateProvider.notifier).startFresh();
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('App started fresh with empty ledger')),
                );
              }
            },
            child: Text('Start Fresh', style: TextStyle(color: theme.coral, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmResetDemoData(BuildContext context) {
    final theme = context.settliv;
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('Reset demo data?', style: TextStyle(color: theme.ink)),
        content: Text(
          'This will restore all default 6-month historical demo groups, expenses, and settlements.',
          style: TextStyle(color: theme.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: theme.muted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(appStateProvider.notifier).resetDemoData();
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Demo data restored')),
                );
              }
            },
            child: Text('Restore Demo', style: TextStyle(color: theme.emerald, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAllData(BuildContext context) {
    final theme = context.settliv;
    final messenger = ScaffoldMessenger.of(context);
    final confirmController = TextEditingController();
    bool canDelete = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.surface,
          title: Text('Delete all my data?', style: TextStyle(color: theme.coral)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This permanently deletes all your local groups, expenses, settlements, and preferences. Type "DELETE" below to confirm.',
                style: TextStyle(color: theme.muted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmController,
                autofocus: true,
                style: TextStyle(color: theme.ink),
                decoration: InputDecoration(
                  hintText: 'Type DELETE',
                  hintStyle: TextStyle(color: theme.muted),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: theme.hairline),
                  ),
                ),
                onChanged: (val) {
                  setDialogState(() {
                    canDelete = val.trim() == 'DELETE';
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: theme.muted)),
            ),
            TextButton(
              onPressed: canDelete
                  ? () async {
                      Navigator.pop(ctx);
                      await ref.read(appStateProvider.notifier).deleteAllData();
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('All data deleted')),
                        );
                      }
                    }
                  : null,
              child: Text(
                'Delete Everything',
                style: TextStyle(
                  color: canDelete ? theme.coral : theme.muted,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final themeMode = ref.watch(themeModeProvider);
    final repo = ref.watch(appRepositoryProvider);
    final user = repo.currentUser;

    return ScreenScaffold(
      hasBottomBar: false,
      header: ScreenHeader(
        title: 'Profile & Settings',
        onBack: () => context.pop(),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Profile Card
            GlassSurface(
              level: GlassLevel.level1,
              borderRadius: 24,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (user != null)
                        PersonAvatar(
                          person: user,
                          size: 56,
                          showRing: true,
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? 'Primary User',
                              style: AppTypography.titleLarge.copyWith(
                                color: theme.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.upiId != null && user!.upiId!.isNotEmpty
                                  ? 'UPI ID saved · ${user.upiId}'
                                  : 'UPI ID not set',
                              style: AppTypography.caption.copyWith(
                                color: user?.upiId != null && user!.upiId!.isNotEmpty
                                    ? theme.textEmerald
                                    : theme.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isEditingProfile ? Icons.close_rounded : Icons.edit_outlined,
                          color: theme.ink,
                        ),
                        onPressed: () {
                          setState(() {
                            _isEditingProfile = !_isEditingProfile;
                            if (_isEditingProfile && user != null) {
                              _nameController.text = user.name;
                              _upiController.text = user.upiId ?? '';
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  if (_isEditingProfile) ...[
                    const SizedBox(height: 20),
                    Divider(color: theme.hairline, height: 1),
                    const SizedBox(height: 16),
                    Text(
                      'Edit Name',
                      style: AppTypography.caption.copyWith(
                        color: theme.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      style: AppTypography.body.copyWith(color: theme.ink),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: theme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.hairline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.hairline),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Your UPI ID (e.g. name@okaxis)',
                      style: AppTypography.caption.copyWith(
                        color: theme.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _upiController,
                      style: AppTypography.body.copyWith(color: theme.ink),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: theme.surface,
                        hintText: 'name@handle',
                        hintStyle: AppTypography.body.copyWith(color: theme.muted),
                        errorText: _upiError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.hairline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.hairline),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryButtonBg,
                          foregroundColor: theme.primaryButtonText,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: _saveProfile,
                        child: const Text('Save Profile'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Appearance Section
            Text(
              'APPEARANCE',
              style: AppTypography.caption.copyWith(
                color: theme.muted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            GlassSurface(
              level: GlassLevel.level1,
              borderRadius: 20,
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  _buildThemeButton(
                    label: 'Light',
                    icon: Icons.light_mode_outlined,
                    isSelected: themeMode == ThemeMode.light,
                    onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light),
                    theme: theme,
                  ),
                  _buildThemeButton(
                    label: 'Dark',
                    icon: Icons.dark_mode_outlined,
                    isSelected: themeMode == ThemeMode.dark,
                    onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark),
                    theme: theme,
                  ),
                  _buildThemeButton(
                    label: 'System',
                    icon: Icons.settings_system_daydream_outlined,
                    isSelected: themeMode == ThemeMode.system,
                    onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system),
                    theme: theme,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Recurring Expenses
            Text(
              'LEDGER FEATURES',
              style: AppTypography.caption.copyWith(
                color: theme.muted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            GlassSurface(
              level: GlassLevel.level1,
              borderRadius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              onTap: () => context.push('/settings/recurring'),
              child: Row(
                children: [
                  Icon(Icons.repeat_rounded, color: theme.navy, size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recurring expenses',
                          style: AppTypography.body.copyWith(
                            color: theme.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Auto-repeating rules and templates',
                          style: AppTypography.caption.copyWith(color: theme.muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.muted,
                    size: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Backup & Restore
            Text(
              'BACKUP & EXPORT',
              style: AppTypography.caption.copyWith(
                color: theme.muted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

            // Export JSON Backup
            GlassSurface(
              level: GlassLevel.level1,
              borderRadius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              onTap: _exportJsonBackup,
              child: Row(
                children: [
                  Icon(Icons.file_download_outlined, color: theme.ink, size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export JSON backup',
                          style: AppTypography.body.copyWith(
                            color: theme.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Copy full ledger data to clipboard',
                          style: AppTypography.caption.copyWith(color: theme.muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: theme.muted, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Export Expenses (CSV)
            GlassSurface(
              level: GlassLevel.level1,
              borderRadius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              onTap: _exportExpensesCsv,
              child: Row(
                children: [
                  Icon(Icons.table_chart_outlined, color: theme.ink, size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export expenses (CSV)',
                          style: AppTypography.body.copyWith(
                            color: theme.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Spreadsheet-compatible expense export',
                          style: AppTypography.caption.copyWith(color: theme.muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: theme.muted, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Restore from JSON Backup
            GlassSurface(
              level: GlassLevel.level1,
              borderRadius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              onTap: _openRestoreDialog,
              child: Row(
                children: [
                  Icon(Icons.file_upload_outlined, color: theme.ink, size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Restore from JSON backup',
                          style: AppTypography.body.copyWith(
                            color: theme.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Restore ledger from clipboard string',
                          style: AppTypography.caption.copyWith(color: theme.muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: theme.muted, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Experience Section
            const ExperienceSettingsSection(),
            const SizedBox(height: 28),

            // Privacy & Data
            Text(
              'PRIVACY & DATA',
              style: AppTypography.caption.copyWith(
                color: theme.muted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            GlassSurface(
              level: GlassLevel.level1,
              borderRadius: 20,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data stays on this device',
                    style: AppTypography.body.copyWith(
                      color: theme.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Settliv is local-first. All your groups, expenses, and personal details stay entirely on this device. Nothing is sent to an external server.',
                    style: AppTypography.caption.copyWith(color: theme.muted),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: theme.hairline, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.hairline),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _confirmStartFresh(context),
                          child: Text('Start fresh', style: TextStyle(color: theme.ink)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.hairline),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _confirmResetDemoData(context),
                          child: Text('Reset demo data', style: TextStyle(color: theme.ink)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.coral),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _confirmDeleteAllData(context),
                      child: Text('Delete all my data', style: TextStyle(color: theme.coral)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // About / Version
            Center(
              child: Column(
                children: [
                  Text(
                    'Settliv v0.2.0',
                    style: AppTypography.caption.copyWith(
                      color: theme.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'v0 prototype with local demo data. More screens and online features come in the full app.',
                    style: AppTypography.caption.copyWith(
                      color: theme.muted,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    ],
  );
}

  Widget _buildThemeButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required SettlivThemeExtension theme,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? theme.primaryButtonBg : theme.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? theme.primaryButtonText : theme.muted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: isSelected ? theme.primaryButtonText : theme.muted,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
