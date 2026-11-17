import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/coming_soon_tag.dart';
import '../../../../core/widgets/glass_sheet_scaffold.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../core/widgets/person_avatar.dart';
import '../../../../data/models/person.dart';

class UserProfileSheet extends ConsumerWidget {
  final Person user;

  const UserProfileSheet({super.key, required this.user});

  static void show(BuildContext context, Person user) {
    GlassSheetScaffold.show(
      context: context,
      title: 'Profile & Settings',
      child: UserProfileSheet(user: user),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.settliv;
    final currentThemeMode = ref.watch(themeModeProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User profile tile in a glass card
        GlassSurface(
          level: GlassLevel.level1,
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          child: Row(
            children: [
              PersonAvatar(
                person: user,
                size: 52,
                showRing: true,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: AppTypography.titleLarge.copyWith(
                        color: theme.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Primary account · UPI verified',
                      style: AppTypography.caption.copyWith(
                        color: theme.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Appearance section
        Text(
          'APPEARANCE',
          style: AppTypography.sectionLabel.copyWith(
            color: theme.secondary,
            letterSpacing: 0.8,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildThemeOption(
              context: context,
              label: 'Light',
              icon: Icons.light_mode_rounded,
              isSelected: currentThemeMode == ThemeMode.light,
              onTap: () => ref
                  .read(themeModeProvider.notifier)
                  .setThemeMode(ThemeMode.light),
            ),
            const SizedBox(width: 8),
            _buildThemeOption(
              context: context,
              label: 'Dark',
              icon: Icons.dark_mode_rounded,
              isSelected: currentThemeMode == ThemeMode.dark,
              onTap: () => ref
                  .read(themeModeProvider.notifier)
                  .setThemeMode(ThemeMode.dark),
            ),
            const SizedBox(width: 8),
            _buildThemeOption(
              context: context,
              label: 'System',
              icon: Icons.brightness_auto_rounded,
              isSelected: currentThemeMode == ThemeMode.system,
              onTap: () => ref
                  .read(themeModeProvider.notifier)
                  .setThemeMode(ThemeMode.system),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Cloud sync & backup item
        GlassSurface(
          level: GlassLevel.level1,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          borderRadius: 18,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cloud Sync & Backup',
                      style: AppTypography.bodyMedium.copyWith(
                        color: theme.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Automated Google Drive & WhatsApp backup',
                      style: AppTypography.caption.copyWith(
                        color: theme.secondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const ComingSoonTag(
                label: 'Full app',
                featureDescription:
                    'Automated cloud synchronization and export features will be available in the full release.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
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

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.sapphireGradient : null,
            color: isSelected
                ? null
                : (context.isDarkMode
                    ? const Color(0x1AFFFFFF)
                    : const Color(0x66FFFFFF)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppColors.sapphireStart
                  : (context.isDarkMode
                      ? const Color(0x26FFFFFF)
                      : const Color(0x4DFFFFFF)),
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.sapphireEnd.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
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
                style: AppTypography.caption.copyWith(
                  color: isSelected ? Colors.white : theme.ink,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
