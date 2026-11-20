import 'package:flutter/material.dart';
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

  static bool hasCountedUpThisSession = false;

  @override
  State<BalanceHeroCard> createState() => _BalanceHeroCardState();
}

class _BalanceHeroCardState extends State<BalanceHeroCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _countUpController;
  late Animation<double> _countUpAnimation;

  @override
  void initState() {
    super.initState();
    _countUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _countUpAnimation = CurvedAnimation(
      parent: _countUpController,
      curve: Curves.easeOutCubic,
    );

    if (BalanceHeroCard.hasCountedUpThisSession) {
      _countUpController.value = 1.0;
    } else {
      BalanceHeroCard.hasCountedUpThisSession = true;
      _countUpController.forward();
    }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final isDark = theme.isDark;
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    if (disableAnimations) {
      _countUpController.value = 1.0;
    }

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

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? theme.hairline : theme.white.withValues(alpha: 0.15),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.shadow.withValues(alpha: isDark ? 0.40 : 0.16),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // 1. Mesh Gradient Background drawn and cached
              Positioned.fill(
                child: CustomPaint(
                  painter: _HeroMeshPainter(
                    startColor: theme.heroMeshStart,
                    endColor: theme.heroMeshEnd,
                    accentColor: theme.heroMeshAccent,
                    isDark: isDark,
                  ),
                ),
              ),

              // 2. Card Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Label
                    Text(
                      'YOUR BALANCE',
                      style: AppTypography.caption.copyWith(
                        color: theme.onNavy.withValues(alpha: 0.70),
                        letterSpacing: 1.0,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // 40-44px money text (tabular figures, tight tracking)
                    AnimatedBuilder(
                      animation: _countUpAnimation,
                      builder: (context, _) {
                        final animatedPaise = (widget.netPaise * _countUpAnimation.value).round();
                        return Text(
                          CurrencyFormatter.formatPaise(
                            animatedPaise,
                            showSign: widget.netPaise != 0,
                            absolute: false,
                          ),
                          style: AppTypography.moneyHero.copyWith(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.2,
                            color: widget.netPaise > 0
                                ? theme.textEmerald
                                : (widget.netPaise < 0 ? theme.textCoral : theme.onNavy),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 2),

                    // Sub line
                    Text(
                      subLine,
                      style: AppTypography.body.copyWith(
                        color: theme.onNavy.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Slim two-segment proportional split bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        height: 5,
                        child: Row(
                          children: [
                            Flexible(
                              flex: (owedRatio * 100).round(),
                              child: Container(
                                color: theme.emerald,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              flex: ((1.0 - owedRatio) * 100).round(),
                              child: Container(
                                color: theme.coral,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Stat row: Owed to you / You owe
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        // Owed to you
                        Text.rich(
                          TextSpan(
                            children: [
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: theme.emerald,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              TextSpan(
                                text: 'Owed to you ',
                                style: AppTypography.caption.copyWith(
                                  color: theme.onNavy.withValues(alpha: 0.75),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                              TextSpan(
                                text: CurrencyFormatter.formatPaise(
                                  widget.totalOwedToUserPaise,
                                  absolute: true,
                                ),
                                style: AppTypography.caption.copyWith(
                                  color: theme.onNavy,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // You owe
                        Text.rich(
                          TextSpan(
                            children: [
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: theme.coral,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              TextSpan(
                                text: 'You owe ',
                                style: AppTypography.caption.copyWith(
                                  color: theme.onNavy.withValues(alpha: 0.75),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                              TextSpan(
                                text: CurrencyFormatter.formatPaise(
                                  widget.totalUserOwesPaise,
                                  absolute: true,
                                ),
                                style: AppTypography.caption.copyWith(
                                  color: theme.onNavy,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroMeshPainter extends CustomPainter {
  final Color startColor;
  final Color endColor;
  final Color accentColor;
  final bool isDark;

  const _HeroMeshPainter({
    required this.startColor,
    required this.endColor,
    required this.accentColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base background fill
    final basePaint = Paint()..color = startColor;
    canvas.drawRect(rect, basePaint);

    // Diagonal gradient mesh
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        startColor,
        endColor,
      ],
    );
    final meshPaint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, meshPaint);

    // Subtle soft radial glow in top right
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.8, -0.6),
        radius: 0.9,
        colors: [
          accentColor.withValues(alpha: isDark ? 0.20 : 0.15),
          startColor.withValues(alpha: 0.0),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _HeroMeshPainter oldDelegate) {
    return startColor != oldDelegate.startColor ||
        endColor != oldDelegate.endColor ||
        accentColor != oldDelegate.accentColor ||
        isDark != oldDelegate.isDark;
  }
}
