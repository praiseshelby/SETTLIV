import 'settliv_wordmark.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../layout/adaptive_layout.dart';
import '../profile/experience_mode.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../theme/theme_provider.dart';
import '../widgets/aurora_background.dart';
import '../widgets/person_avatar.dart';
import '../../data/repositories/in_memory_app_repository.dart';

class AdaptiveWebShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AdaptiveWebShell({
    super.key,
    required this.navigationShell,
  });

  @override
  ConsumerState<AdaptiveWebShell> createState() => _AdaptiveWebShellState();
}

class _AdaptiveWebShellState extends ConsumerState<AdaptiveWebShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final layout = AdaptiveLayout.of(context);
    final isCompact = layout == LayoutClass.compact;
    final isMedium = layout == LayoutClass.medium;

    if (isCompact) {
      return _buildCompactWeb(context, theme);
    } else if (isMedium) {
      return _buildMediumWeb(context, theme);
    } else {
      return _buildExpandedWeb(context, theme);
    }
  }

  // 1. Compact Web (< 720): sticky top glass header + drawer, NO bottom bar
  Widget _buildCompactWeb(BuildContext context, SettlivThemeExtension theme) {

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.canvas,
      drawer: _buildWebDrawer(context, theme),
      body: AuroraBackground(
        child: Column(
          children: [
            // Sticky glass top header
            ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: theme.surface.withValues(alpha: 0.85),
                    border: Border(bottom: BorderSide(color: theme.hairline)),
                  ),
                  child: Row(
                    children: [
                      // Menu trigger on left
                      IconButton(
                        icon: const Icon(Icons.menu_rounded),
                        color: theme.ink,
                        tooltip: 'Menu',
                        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      ),
                      const SizedBox(width: 8),
                      // Wordmark beside menu button
                      const SettlivWordmark(fontSize: 16),
                      const Spacer(),
                      // Add button
                      IconButton(
                        icon: const Icon(Icons.add_rounded),
                        color: theme.ink,
                        tooltip: 'Add expense',
                        onPressed: () => context.push('/add'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Page content
            Expanded(
              child: widget.navigationShell,
            ),
          ],
        ),
      ),
    );
  }

  // 2. Medium Web (720-1099): 76px icon rail + centered content
  Widget _buildMediumWeb(BuildContext context, SettlivThemeExtension theme) {
    return Scaffold(
      backgroundColor: theme.canvas,
      body: AuroraBackground(
        child: Row(
          children: [
            // 76px Icon Rail
            _buildIconRail(context, theme),
            // Main content
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: AdaptiveLayout.maxContentWidth),
                  child: widget.navigationShell,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. Expanded Web (>= 1100): 264px glass sidebar + centered content
  Widget _buildExpandedWeb(BuildContext context, SettlivThemeExtension theme) {
    return Scaffold(
      backgroundColor: theme.canvas,
      body: AuroraBackground(
        child: Row(
          children: [
            // 264px Glass Sidebar
            _buildSidebar(context, theme),
            // Main content area
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: AdaptiveLayout.maxContentWidth),
                  child: widget.navigationShell,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, SettlivThemeExtension theme) {
    final currentBranch = widget.navigationShell.currentIndex;
    final repo = ref.watch(appRepositoryProvider);
    final user = repo.currentUser;

    return Container(
      width: 264,
      height: double.infinity,
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.82),
        border: Border(right: BorderSide(color: theme.hairline)),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header: SETTLIV wordmark (~18px, left-aligned with nav items' text column)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 24),
                  child: SettlivWordmark(fontSize: 18),
                ),

                // Primary "Add expense" button
                ElevatedButton.icon(
                  onPressed: () => context.push('/add'),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Add expense'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accent,
                    foregroundColor: theme.white,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: AppTypography.bodySemiBold.copyWith(fontSize: 14),
                  ),
                ),
                const SizedBox(height: 24),

                // Nav Links
                _buildNavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  isSelected: currentBranch == 0,
                  onTap: () => widget.navigationShell.goBranch(0),
                  theme: theme,
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  icon: Icons.group_rounded,
                  label: 'Groups',
                  isSelected: currentBranch == 1,
                  onTap: () => widget.navigationShell.goBranch(1),
                  theme: theme,
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Records',
                  isSelected: currentBranch == 2,
                  onTap: () => widget.navigationShell.goBranch(2),
                  theme: theme,
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  icon: Icons.auto_graph_rounded,
                  label: 'Insights',
                  isSelected: currentBranch == 3,
                  onTap: () => widget.navigationShell.goBranch(3),
                  theme: theme,
                ),
                // Budgets nested under Insights
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 2),
                  child: _buildNavItem(
                    icon: Icons.pie_chart_outline_rounded,
                    label: 'Budgets & Plan',
                    isSelected: false,
                    onTap: () => context.go('/insights/budgets'),
                    theme: theme,
                    dense: true,
                  ),
                ),

                const Spacer(),

                // Version micro-card
                InkWell(
                  onTap: () => context.push('/settings'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.canvas.withValues(alpha: 0.60),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.hairline),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.devices_rounded, size: 16, color: theme.muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Runs as mobile app & website',
                            style: AppTypography.caption.copyWith(
                              color: theme.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 14, color: theme.muted),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Footer: Avatar row + Theme toggle
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => context.push('/settings'),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: Row(
                            children: [
                              PersonAvatar(person: user, size: 32),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  user?.name ?? 'Settliv',
                                  style: AppTypography.bodySemiBold.copyWith(
                                    color: theme.ink,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Theme toggle
                    IconButton(
                      icon: Icon(
                        theme.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        size: 20,
                      ),
                      color: theme.muted,
                      tooltip: theme.isDark ? 'Light mode' : 'Dark mode',
                      onPressed: () {
                        final currentTheme = ref.read(themeModeProvider);
                        final next = currentTheme == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
                        ref.read(themeModeProvider.notifier).setThemeMode(next);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconRail(BuildContext context, SettlivThemeExtension theme) {
    final currentBranch = widget.navigationShell.currentIndex;

    return Container(
      width: 76,
      height: double.infinity,
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.85),
        border: Border(right: BorderSide(color: theme.hairline)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 28),
          const Center(
            child: SettlivWordmark(
              fontSize: 13,
              rotated: true,
            ),
          ),
          const SizedBox(height: 28),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            color: theme.accent,
            tooltip: 'Add expense',
            onPressed: () => context.push('/add'),
          ),
          const SizedBox(height: 12),
          _buildRailIcon(
            icon: Icons.dashboard_rounded,
            tooltip: 'Dashboard',
            isSelected: currentBranch == 0,
            onTap: () => widget.navigationShell.goBranch(0),
            theme: theme,
          ),
          _buildRailIcon(
            icon: Icons.group_rounded,
            tooltip: 'Groups',
            isSelected: currentBranch == 1,
            onTap: () => widget.navigationShell.goBranch(1),
            theme: theme,
          ),
          _buildRailIcon(
            icon: Icons.receipt_long_rounded,
            tooltip: 'Records',
            isSelected: currentBranch == 2,
            onTap: () => widget.navigationShell.goBranch(2),
            theme: theme,
          ),
          _buildRailIcon(
            icon: Icons.auto_graph_rounded,
            tooltip: 'Insights',
            isSelected: currentBranch == 3,
            onTap: () => widget.navigationShell.goBranch(3),
            theme: theme,
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            color: theme.muted,
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            icon: Icon(
              theme.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
            color: theme.muted,
            tooltip: theme.isDark ? 'Light mode' : 'Dark mode',
            onPressed: () {
              final currentTheme = ref.read(themeModeProvider);
              final next = currentTheme == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
              ref.read(themeModeProvider.notifier).setThemeMode(next);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildWebDrawer(BuildContext context, SettlivThemeExtension theme) {
    final profile = ref.watch(deviceProfileProvider);

    return Drawer(
      backgroundColor: theme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: SettlivWordmark(fontSize: 18),
              ),
              const SizedBox(height: 28),
              ListTile(
                leading: const Icon(Icons.dashboard_rounded),
                title: const Text('Dashboard'),
                onTap: () {
                  Navigator.pop(context);
                  widget.navigationShell.goBranch(0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_rounded),
                title: const Text('Groups'),
                onTap: () {
                  Navigator.pop(context);
                  widget.navigationShell.goBranch(1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_rounded),
                title: const Text('Records'),
                onTap: () {
                  Navigator.pop(context);
                  widget.navigationShell.goBranch(2);
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_graph_rounded),
                title: const Text('Insights'),
                onTap: () {
                  Navigator.pop(context);
                  widget.navigationShell.goBranch(3);
                },
              ),
              ListTile(
                leading: const Icon(Icons.pie_chart_outline_rounded),
                title: const Text('Budgets & Plan'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/insights/budgets');
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/settings');
                },
              ),
              const Spacer(),

              // Switch to app view (touch devices only)
              if (profile.isTouch) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ref.read(experienceModeProvider.notifier).setMode(ExperienceMode.app);
                  },
                  icon: const Icon(Icons.phone_iphone_rounded, size: 18),
                  label: const Text('Switch to app view'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.accent,
                    side: BorderSide(color: theme.accent.withValues(alpha: 0.5)),
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Version info
              Text(
                'One codebase, two experiences.\nSettliv Web 1.0',
                style: AppTypography.caption.copyWith(color: theme.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required SettlivThemeExtension theme,
    bool dense = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: dense ? 36 : 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.accent.withValues(alpha: 0.12) : theme.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: dense ? 17 : 20,
              color: isSelected ? theme.accent : theme.ink.withValues(alpha: 0.75),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: AppTypography.fontBody,
                  fontSize: dense ? 13 : 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? theme.accent : theme.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRailIcon({
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onTap,
    required SettlivThemeExtension theme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        color: isSelected ? theme.accent : theme.muted,
        onPressed: onTap,
      ),
    );
  }


}
