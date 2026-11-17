import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../utils/currency_formatter.dart';
import 'glass_surface.dart';

class BalanceHeroCard extends StatefulWidget {
  final int netPaise;
  final int totalOwedToUserPaise;
  final int totalUserOwesPaise;

  const BalanceHeroCard({
    super.key,
    required this.netPaise,
    required this.totalOwedToUserPaise,
    required this.totalUserOwesPaise,
  });

  @override
  State<BalanceHeroCard> createState() => _BalanceHeroCardState();
}

class _BalanceHeroCardState extends State<BalanceHeroCard>
    with TickerProviderStateMixin {
  late AnimationController _countUpController;
  late Animation<double> _countUpAnimation;

  late AnimationController _sheenController;
  late Animation<double> _sheenAnimation;

  @override
  void initState() {
    super.initState();
    _countUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _countUpAnimation = CurvedAnimation(
      parent: _countUpController,
      curve: Curves.easeOutCubic,
    );

    _sheenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _sheenAnimation = CurvedAnimation(
      parent: _sheenController,
      curve: Curves.easeInOutCubic,
    );

    _countUpController.forward();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _sheenController.forward();
    });
  }

  @override
  void didUpdateWidget(covariant BalanceHeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.netPaise != widget.netPaise) {
      _countUpController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _countUpController.dispose();
    _sheenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final isDark = context.isDarkMode;

    final String subLine;
    if (widget.netPaise > 0) {
      subLine = "Overall, you're owed";
    } else if (widget.netPaise < 0) {
      subLine = "Overall, you owe";
    } else {
      subLine = "All settled up";
    }

    final int total = widget.totalOwedToUserPaise + widget.totalUserOwesPaise;
    final double owedRatio = total > 0
        ? (widget.totalOwedToUserPaise / total).clamp(0.05, 0.95)
        : 0.5;

    return GlassSurface(
      level: GlassLevel.level3,
      borderRadius: 28,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Label
              Text(
                'YOUR BALANCE',
                style: AppTypography.sectionLabel.copyWith(
                  color: theme.secondary,
                  letterSpacing: 1.0,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),

              // 2. 52/700 count-up number
              AnimatedBuilder(
                animation: _countUpAnimation,
                builder: (context, _) {
                  final animatedPaise =
                      (widget.netPaise * _countUpAnimation.value).round();
                  return Text(
                    CurrencyFormatter.formatPaise(
                      animatedPaise,
                      showSign: widget.netPaise != 0,
                      absolute: false,
                    ),
                    style: AppTypography.heroMoney.copyWith(
                      color: widget.netPaise > 0
                          ? AppColors.emerald
                          : (widget.netPaise < 0 ? AppColors.coral : theme.ink),
                      letterSpacing: -1.8,
                    ),
                  );
                },
              ),
              const SizedBox(height: 2),

              // 3. Sub line
              Text(
                subLine,
                style: AppTypography.body.copyWith(
                  color: theme.secondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),

              // 4. Slim two-segment proportional split bar
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 6,
                  child: Row(
                    children: [
                      Flexible(
                        flex: (owedRatio * 100).round(),
                        child: Container(
                          color: AppColors.emerald,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        flex: ((1.0 - owedRatio) * 100).round(),
                        child: Container(
                          color: AppColors.coral,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 5. Two stat columns with colour dots
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Owed to you
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.emerald,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text.rich(
                            TextSpan(
                              text: 'Owed to you ',
                              style: AppTypography.caption.copyWith(
                                color: theme.secondary,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                              children: [
                                TextSpan(
                                  text: CurrencyFormatter.formatPaise(
                                    widget.totalOwedToUserPaise,
                                    absolute: true,
                                  ),
                                  style: AppTypography.caption.copyWith(
                                    color: theme.ink,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // You owe
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.coral,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text.rich(
                            TextSpan(
                              text: 'You owe ',
                              style: AppTypography.caption.copyWith(
                                color: theme.secondary,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                              children: [
                                TextSpan(
                                  text: CurrencyFormatter.formatPaise(
                                    widget.totalUserOwesPaise,
                                    absolute: true,
                                  ),
                                  style: AppTypography.caption.copyWith(
                                    color: theme.ink,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Sheen sweep on load
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _sheenAnimation,
                builder: (context, _) {
                  if (_sheenAnimation.value <= 0.0 ||
                      _sheenAnimation.value >= 1.0) {
                    return const SizedBox.shrink();
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final double left =
                          (constraints.maxWidth + 120) * _sheenAnimation.value -
                              120;
                      return Transform.translate(
                        offset: Offset(left, 0),
                        child: Container(
                          width: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white.withValues(
                                    alpha: isDark ? 0.08 : 0.25),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                              transform: const GradientRotation(math.pi / 4),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
