import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../../data/repositories/in_memory_app_repository.dart';
import '../../features/home/presentation/widgets/user_profile_sheet.dart';

class FloatingNavBar extends ConsumerStatefulWidget {
  final String currentPath;

  const FloatingNavBar({
    super.key,
    required this.currentPath,
  });

  @override
  ConsumerState<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends ConsumerState<FloatingNavBar>
    with SingleTickerProviderStateMixin {
  bool _isAddPressed = false;

  int _getSelectedIndex() {
    if (widget.currentPath == '/groups') return 1;
    if (widget.currentPath == '/activity') return 2;
    return 0; // Home is default
  }

  bool _shouldHideBar(BuildContext context) {
    // Hide bar on Add Expense and Group Detail
    if (widget.currentPath == '/add') return true;
    if (widget.currentPath.startsWith('/group/')) return true;

    // Hide bar when keyboard is open
    if (MediaQuery.of(context).viewInsets.bottom > 0) return true;

    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldHideBar(context)) {
      return const SizedBox.shrink();
    }

    final theme = context.settliv;
    final isDark = context.isDarkMode;
    final selectedIndex = _getSelectedIndex();
    final repo = ref.watch(appRepositoryProvider);
    final currentUser = repo.currentUser;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          height: 68,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // Main frosted bar (~64px tall)
              Material(
                color: Colors.transparent,
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xE6151B28) // Frosted dark Pearl
                        : const Color(0xF2F5F8FC), // Frosted light Pearl
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.14)
                          : Colors.white.withValues(alpha: 0.55),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Slot 0: Home
                      Expanded(
                        child: Center(
                          child: _buildNavItem(
                            index: 0,
                            label: 'Home',
                            icon: Icons.home_outlined,
                            activeIcon: Icons.home_rounded,
                            isSelected: selectedIndex == 0,
                            onTap: () {
                              if (widget.currentPath != '/') {
                                context.go('/');
                              }
                            },
                          ),
                        ),
                      ),

                      // Slot 1: Groups
                      Expanded(
                        child: Center(
                          child: _buildNavItem(
                            index: 1,
                            label: 'Groups',
                            icon: Icons.groups_outlined,
                            activeIcon: Icons.groups_rounded,
                            isSelected: selectedIndex == 1,
                            onTap: () {
                              if (widget.currentPath != '/groups') {
                                context.go('/groups');
                              }
                            },
                          ),
                        ),
                      ),

                      // Spacer for the center '+' button (52px wide)
                      const SizedBox(width: 52),

                      // Slot 3: Activity
                      Expanded(
                        child: Center(
                          child: _buildNavItem(
                            index: 2,
                            label: 'Activity',
                            icon: Icons.receipt_long_outlined,
                            activeIcon: Icons.receipt_long_rounded,
                            isSelected: selectedIndex == 2,
                            onTap: () {
                              if (widget.currentPath != '/activity') {
                                context.go('/activity');
                              }
                            },
                          ),
                        ),
                      ),

                      // Slot 4: You (opens profile sheet, does not change tab)
                      Expanded(
                        child: Center(
                          child: Semantics(
                            button: true,
                            label: 'Your profile and settings',
                            child: InkWell(
                              onTap: () {
                                if (currentUser != null) {
                                  UserProfileSheet.show(context, currentUser);
                                }
                              },
                              borderRadius: BorderRadius.circular(999),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 6),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.person_outline_rounded,
                                        size: 22,
                                        color: theme.secondary,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'You',
                                        style: AppTypography.caption.copyWith(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: theme.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Centre "+" button (52px Sapphire circle, sits proud)
              Positioned(
                top: 0,
                child: Semantics(
                  button: true,
                  label: 'Add expense',
                  child: GestureDetector(
                    onTapDown: (_) => setState(() => _isAddPressed = true),
                    onTapUp: (_) => setState(() => _isAddPressed = false),
                    onTapCancel: () => setState(() => _isAddPressed = false),
                    onTap: () {
                      context.push('/add');
                    },
                    child: AnimatedScale(
                      scale: _isAddPressed ? 0.94 : 1.0,
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOut,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.sapphire,
                              Color(0xFF1E5BB5),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.sapphire
                                  .withValues(alpha: isDark ? 0.45 : 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.add_rounded,
                            size: 28,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = context.settliv;
    final isDark = context.isDarkMode;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 10 : 6,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? AppColors.sapphire.withValues(alpha: 0.22)
                    : AppColors.sapphire.withValues(alpha: 0.12))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 21,
                  color: isSelected ? AppColors.sapphire : theme.secondary,
                ),
                if (isSelected) ...[
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: AppTypography.chip.copyWith(
                      color: AppColors.sapphire,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
