import 'settliv_wordmark.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../layout/adaptive_layout.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../theme/theme_provider.dart';
import '../widgets/aurora_background.dart';
import '../widgets/person_avatar.dart';
import '../../data/repositories/in_memory_app_repository.dart';
import 'first_visit_compatibility_card.dart';
import 'magnetic_button.dart';

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

  String _getCurrentPath(BuildContext context) {
    try {
      return GoRouterState.of(context).matchedLocation;
    } catch (_) {
      return '/';
    }
  }

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
        child: Stack(
          children: [
            Column(
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
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    theme.accent.withValues(alpha: 0.35),
                                    theme.hairline,
                                    theme.hairline.withValues(alpha: 0.20),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Row(
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
            // First visit compatibility toast/card
            const Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: FirstVisitCompatibilityCard(),
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
        child: Stack(
          children: [
            Row(
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
            const Positioned(
              right: 24,
              bottom: 24,
              child: FirstVisitCompatibilityCard(),
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
        child: Stack(
          children: [
            Row(
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
            const Positioned(
              right: 24,
              bottom: 24,
              child: FirstVisitCompatibilityCard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, SettlivThemeExtension theme) {
    final currentPath = _getCurrentPath(context);
    final repo = ref.watch(appRepositoryProvider);
    final user = repo.currentUser;

    final isDashboardActive = currentPath == '/';
    final isGroupsActive = currentPath.startsWith('/groups') || currentPath.startsWith('/group');
    final isRecordsActive = currentPath.startsWith('/records');
    final isInsightsActive = currentPath == '/insights';
    final isBudgetsActive = currentPath.startsWith('/budgets') || currentPath == '/insights/budgets';

    return Container(
      width: 264,
      height: double.infinity,
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.82),
      ),
      child: Stack(
        children: [
          Positioned.fill(
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

                      // Primary "Add expense" button with subtle magnetic pull
                      MagneticButton(
                        child: ElevatedButton.icon(
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
                      ),
                      const SizedBox(height: 24),

                // Group 1: OVERVIEW
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  child: Text(
                    'OVERVIEW',
                    style: AppTypography.eyebrow.copyWith(
                      color: theme.muted,
                      letterSpacing: 0.8,
                      fontSize: 10,
                    ),
                  ),
                ),
                _buildNavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  isSelected: isDashboardActive,
                  onTap: () => context.go('/'),
                  theme: theme,
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  icon: Icons.group_rounded,
                  label: 'Groups',
                  isSelected: isGroupsActive,
                  onTap: () => context.go('/groups'),
                  theme: theme,
                ),
                const SizedBox(height: 18),

                // Group 2: MONEY
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  child: Text(
                    'MONEY',
                    style: AppTypography.eyebrow.copyWith(
                      color: theme.muted,
                      letterSpacing: 0.8,
                      fontSize: 10,
                    ),
                  ),
                ),
                _buildNavItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Records',
                  isSelected: isRecordsActive,
                  onTap: () => context.go('/records'),
                  theme: theme,
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  icon: Icons.auto_graph_rounded,
                  label: 'Insights',
                  isSelected: isInsightsActive,
                  onTap: () => context.go('/insights'),
                  theme: theme,
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  icon: Icons.pie_chart_outline_rounded,
                  label: 'Budgets',
                  isSelected: isBudgetsActive,
                  onTap: () => context.go('/budgets'),
                  theme: theme,
                ),

                const Spacer(),

                // Compatibility preview card
                InkWell(
                  onTap: () => context.push('/settings'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.canvas.withValues(alpha: 0.60),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.hairline),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.devices_rounded, size: 16, color: theme.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Compatibility preview',
                                style: AppTypography.caption.copyWith(
                                  color: theme.ink,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'PC · Mobile web · App',
                                style: AppTypography.caption.copyWith(
                                  color: theme.muted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
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
    ),
    // Subtle gradient edge highlight on right border
    Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: 1.0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.accent.withValues(alpha: 0.35),
              theme.hairline,
              theme.hairline.withValues(alpha: 0.15),
            ],
            stops: const [0.0, 0.40, 1.0],
          ),
        ),
      ),
    ),
  ],
),
);
  }

  Widget _buildIconRail(BuildContext context, SettlivThemeExtension theme) {
    final currentPath = _getCurrentPath(context);

    final isDashboardActive = currentPath == '/';
    final isGroupsActive = currentPath.startsWith('/groups') || currentPath.startsWith('/group');
    final isRecordsActive = currentPath.startsWith('/records');
    final isInsightsActive = currentPath == '/insights';
    final isBudgetsActive = currentPath.startsWith('/budgets') || currentPath == '/insights/budgets';

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
            isSelected: isDashboardActive,
            onTap: () => context.go('/'),
            theme: theme,
          ),
          _buildRailIcon(
            icon: Icons.group_rounded,
            tooltip: 'Groups',
            isSelected: isGroupsActive,
            onTap: () => context.go('/groups'),
            theme: theme,
          ),
          _buildRailIcon(
            icon: Icons.receipt_long_rounded,
            tooltip: 'Records',
            isSelected: isRecordsActive,
            onTap: () => context.go('/records'),
            theme: theme,
          ),
          _buildRailIcon(
            icon: Icons.auto_graph_rounded,
            tooltip: 'Insights',
            isSelected: isInsightsActive,
            onTap: () => context.go('/insights'),
            theme: theme,
          ),
          _buildRailIcon(
            icon: Icons.pie_chart_outline_rounded,
            tooltip: 'Budgets',
            isSelected: isBudgetsActive,
            onTap: () => context.go('/budgets'),
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
                  context.go('/');
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_rounded),
                title: const Text('Groups'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/groups');
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_rounded),
                title: const Text('Records'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/records');
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_graph_rounded),
                title: const Text('Insights'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/insights');
                },
              ),
              ListTile(
                leading: const Icon(Icons.pie_chart_outline_rounded),
                title: const Text('Budgets'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/budgets');
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

              // Compatibility preview drawer entry
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  context.push('/settings');
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.canvas.withValues(alpha: 0.60),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.hairline),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.devices_rounded, size: 18, color: theme.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Compatibility preview',
                              style: AppTypography.caption.copyWith(
                                color: theme.ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'PC · Mobile web · App',
                              style: AppTypography.caption.copyWith(
                                color: theme.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 16, color: theme.muted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.accent.withValues(alpha: theme.isDark ? 0.14 : 0.08)
              : theme.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Center(
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected ? theme.accent : theme.muted,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodySemiBold.copyWith(
                  color: isSelected ? theme.accent : theme.ink,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected)
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: theme.accent,
                  borderRadius: BorderRadius.circular(2),
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
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.accent.withValues(alpha: 0.12)
                  : theme.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              width: 24,
              height: 24,
              child: Center(
                child: Icon(
                  icon,
                  size: 22,
                  color: isSelected ? theme.accent : theme.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
