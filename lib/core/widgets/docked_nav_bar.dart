import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class DockedNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const DockedNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  State<DockedNavBar> createState() => _DockedNavBarState();
}

class _DockedNavBarState extends State<DockedNavBar> {
  bool _isAddPressed = false;

  void _onTabTapped(int index) {
    HapticFeedback.selectionClick();
    widget.onTabSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final isDark = theme.isDark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    const barBodyHeight = 64.0;
    const plusRaise = 12.0;
    final totalHeight = barBodyHeight + plusRaise + bottomPadding;

    // 5 slots: Slot 0 (Home), Slot 1 (Groups), Slot 2 (+), Slot 3 (Records), Slot 4 (Insights)
    // Map widget.currentIndex (0, 1, 2, 3) to slot center fractions:
    // 0 (Home) -> 0.10
    // 1 (Groups) -> 0.30
    // 2 (Records) -> 0.70
    // 3 (Insights) -> 0.90
    double targetFraction = 0.10;
    if (widget.currentIndex == 1) targetFraction = 0.30;
    if (widget.currentIndex == 2) targetFraction = 0.70;
    if (widget.currentIndex == 3) targetFraction = 0.90;

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth;
        // 3x20 indicator line centered over active tab: (barWidth * fraction) - 10.0
        final indicatorX = (barWidth * targetFraction) - 10.0;

        return SizedBox(
          height: totalHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Docked full-width bar at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: barBodyHeight + bottomPadding,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: EdgeInsets.only(bottom: bottomPadding),
                      decoration: BoxDecoration(
                        color: theme.barSurface,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                        border: Border(
                          top: BorderSide(color: theme.hairline, width: 1.0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.shadow.withOpacity(isDark ? 0.35 : 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // 3x20 active indicator line centered over the active tab sliding along the bar's top edge (200ms)
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            left: indicatorX,
                            top: 0,
                            child: Container(
                              width: 20,
                              height: 3,
                              decoration: BoxDecoration(
                                color: theme.ink,
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                            ),
                          ),
                          // 5 equal slots row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Slot 0: Home
                              Expanded(
                                child: _buildTabItem(
                                  label: 'Home',
                                  icon: Icons.home_outlined,
                                  activeIcon: Icons.home_rounded,
                                  isActive: widget.currentIndex == 0,
                                  onTap: () => _onTabTapped(0),
                                  theme: theme,
                                ),
                              ),
                              // Slot 1: Groups
                              Expanded(
                                child: _buildTabItem(
                                  label: 'Groups',
                                  icon: Icons.groups_outlined,
                                  activeIcon: Icons.groups_rounded,
                                  isActive: widget.currentIndex == 1,
                                  onTap: () => _onTabTapped(1),
                                  theme: theme,
                                ),
                              ),
                              // Slot 2: Centre + placeholder space
                              const Expanded(
                                child: SizedBox.shrink(),
                              ),
                              // Slot 3: Records
                              Expanded(
                                child: _buildTabItem(
                                  label: 'Records',
                                  icon: Icons.receipt_long_outlined,
                                  activeIcon: Icons.receipt_long_rounded,
                                  isActive: widget.currentIndex == 2,
                                  onTap: () => _onTabTapped(2),
                                  theme: theme,
                                ),
                              ),
                              // Slot 4: Insights
                              Expanded(
                                child: _buildTabItem(
                                  label: 'Insights',
                                  icon: Icons.insights_outlined,
                                  activeIcon: Icons.insights_rounded,
                                  isActive: widget.currentIndex == 3,
                                  onTap: () => _onTabTapped(3),
                                  theme: theme,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Centre +: 52x52 rounded square radius 18, indigo-navy (light) / off-white (dark), raised 12px, soft shadow + hairline, NO coloured ring, press scale 0.94
              Positioned(
                left: (barWidth - 52) / 2,
                top: 0,
                child: Semantics(
                  label: 'Add expense',
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => setState(() => _isAddPressed = true),
                    onTapUp: (_) => setState(() => _isAddPressed = false),
                    onTapCancel: () => setState(() => _isAddPressed = false),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.push('/add');
                    },
                    child: AnimatedScale(
                      scale: _isAddPressed ? 0.94 : 1.0,
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOutCubic,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isDark ? theme.primaryButtonBg : theme.navy,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? theme.hairline : theme.white.withOpacity(0.15),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.shadow.withOpacity(isDark ? 0.40 : 0.20),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.add_rounded,
                            size: 28,
                            color: isDark ? theme.primaryButtonText : theme.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabItem({
    required String label,
    required IconData icon,
    required IconData activeIcon,
    required bool isActive,
    required VoidCallback onTap,
    required SettlivThemeExtension theme,
  }) {
    final color = isActive ? theme.ink : theme.muted;

    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      child: Material(
        color: theme.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: theme.transparent,
          highlightColor: theme.transparent,
          child: Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 56),
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  size: 24,
                  color: color,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: AppTypography.tabLabel.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
