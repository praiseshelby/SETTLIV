import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/coming_soon_tag.dart';
import '../../../../core/widgets/person_avatar.dart';
import '../../../../core/widgets/sheet_scaffold.dart';
import '../../../../data/models/person.dart';

class UserProfileSheet extends ConsumerWidget {
  final Person user;

  const UserProfileSheet({super.key, required this.user});

  static void show(BuildContext context, Person user) {
    SheetScaffold.show(
      context: context,
      isScrollControlled: false,
      builder: (ctx) => UserProfileSheet(user: user),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.settliv;
    final currentThemeMode = ref.watch(themeModeProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PersonAvatar(
                person: user,
                size: 52,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: AppTypography.titleLarge.copyWith(color: theme.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Primary account',
                      style: AppTypography.caption.copyWith(color: theme.secondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Appearance',
            style: AppTypography.caption.copyWith(
              color: theme.secondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.raised,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.hairline),
            ),
            child: Row(
              children: [
                _buildThemeOption(
                  context: context,
                  label: 'System',
                  icon: Icons.brightness_auto_rounded,
                  isSelected: currentThemeMode == ThemeMode.system,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(ThemeMode.system),
                ),
                _buildThemeOption(
                  context: context,
                  label: 'Light',
                  icon: Icons.light_mode_rounded,
                  isSelected: currentThemeMode == ThemeMode.light,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(ThemeMode.light),
                ),
                _buildThemeOption(
                  context: context,
                  label: 'Dark',
                  icon: Icons.dark_mode_rounded,
                  isSelected: currentThemeMode == ThemeMode.dark,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(ThemeMode.dark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sync & Backup',
                    style: AppTypography.bodyMedium.copyWith(color: theme.ink),
                  ),
                  Text(
                    'Cloud storage & family export',
                    style: AppTypography.caption.copyWith(color: theme.secondary),
                  ),
                ],
              ),
              const ComingSoonTag(label: 'Back up & more · full app'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = context.settliv;
    final isDark = context.isDarkMode;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF263760) : AppColors.midnightNavy)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : theme.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.chip.copyWith(
                  color: isSelected ? Colors.white : theme.secondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
