import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../utils/currency_formatter.dart';

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
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _lastPaise = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _animation = Tween<double>(
      begin: 0,
      end: widget.netPaise.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    _lastPaise = widget.netPaise;
  }

  @override
  void didUpdateWidget(covariant BalanceHeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.netPaise != widget.netPaise) {
      _animation = Tween<double>(
        begin: _lastPaise.toDouble(),
        end: widget.netPaise.toDouble(),
      ).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _lastPaise = widget.netPaise;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    final String stateWord;
    if (widget.netPaise > 0) {
      stateWord = 'You are owed in total';
    } else if (widget.netPaise < 0) {
      stateWord = 'You owe in total';
    } else {
      stateWord = 'All balances settled';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF142144),
                  const Color(0xFF192955),
                  const Color(0xFF101934),
                ]
              : [
                  AppColors.midnightNavy,
                  AppColors.navy600,
                  const Color(0xFF111D3C),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.midnightNavy.withValues(alpha: isDark ? 0.4 : 0.22),
            blurRadius: 28,
            offset: const Offset(0, 12),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle corner glow bloom (teal/emerald)
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.teal.withValues(alpha: 0.18),
                    AppColors.emerald.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Inner hairline highlight border
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Net balance',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          stateWord,
                          style: AppTypography.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    final int animatedPaise = _animation.value.round();
                    final formatted = CurrencyFormatter.formatPaise(
                      animatedPaise,
                      absolute: true,
                    );
                    return Text(
                      formatted,
                      style: AppTypography.displayMoney.copyWith(
                        color: Colors.white,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                // Stat chips row
                Row(
                  children: [
                    // Owed to you (emerald chip)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.emeraldBright.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Owed to you',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.emeraldBright,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyFormatter.formatPaise(
                                widget.totalOwedToUserPaise,
                                absolute: true,
                              ),
                              style: AppTypography.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // You owe (coral chip)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.coral.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.coralBright.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'You owe',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.coralBright,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyFormatter.formatPaise(
                                widget.totalUserOwesPaise,
                                absolute: true,
                              ),
                              style: AppTypography.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
