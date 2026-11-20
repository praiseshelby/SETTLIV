import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../utils/currency_formatter.dart';
import '../../data/models/person.dart';
import 'person_avatar.dart';

class BalanceHeroCard extends StatefulWidget {
  final int netPaise;
  final int totalOwedToUserPaise;
  final int totalUserOwesPaise;
  final int owedFromCount;
  final int owesToCount;
  final List<Person> counterparties;
  final VoidCallback? onTap;

  const BalanceHeroCard({
    super.key,
    required this.netPaise,
    required this.totalOwedToUserPaise,
    required this.totalUserOwesPaise,
    this.owedFromCount = 0,
    this.owesToCount = 0,
    this.counterparties = const [],
    this.onTap,
  });

  static bool hasCountedUpThisSession = false;

  @override
  State<BalanceHeroCard> createState() => _BalanceHeroCardState();
}

class _BalanceHeroCardState extends State<BalanceHeroCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _countUpController;
  late Animation<double> _countUpAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _countUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
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
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      _countUpController.value = 1.0;
    }

    final String headlineSentence;
    Color? statusDotColor;
    if (widget.netPaise > 0) {
      headlineSentence = "You're owed";
      statusDotColor = theme.textEmerald; // On dark: 4FE3B8
    } else if (widget.netPaise < 0) {
      headlineSentence = "You owe";
      statusDotColor = theme.textCoral; // On dark: FF8D7C
    } else {
      headlineSentence = "All settled up";
      statusDotColor = null;
    }

    final int total = widget.totalOwedToUserPaise + widget.totalUserOwesPaise;
    final double owedRatio = total > 0
        ? (widget.totalOwedToUserPaise / total).clamp(0.05, 0.95)
        : 0.5;

    return Semantics(
      button: true,
      label: 'Net balance across groups. Tap to view breakdown.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap?.call();
        },
        child: AnimatedScale(
          scale: _isPressed ? 0.99 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: RepaintBoundary(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? theme.hairline : theme.white.withValues(alpha: 0.15),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadow.withValues(alpha: isDark ? 0.45 : 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // 1. Deep Indigo-Navy Mesh with faint violet corner glow
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

                    // 2. 1px inner top highlight
                    Positioned(
                      top: 0,
                      left: 12,
                      right: 12,
                      height: 1.0,
                      child: Container(
                        color: theme.white.withValues(alpha: 0.20),
                      ),
                    ),

                    // 3. Card Content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Eyebrow: "NET ACROSS GROUPS" (never "Your balance")
                          Row(
                            children: [
                              Text(
                                'NET ACROSS GROUPS',
                                style: AppTypography.eyebrow.copyWith(
                                  color: theme.white.withValues(alpha: 0.70),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (statusDotColor != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: statusDotColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Headline sentence: "You're owed" / "You owe" / "All settled up"
                          Text(
                            headlineSentence,
                            style: AppTypography.body.copyWith(
                              color: theme.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Big amount in WHITE Sora 40-44/800 with count-up, NO minus sign, never red/green text on navy
                          AnimatedBuilder(
                            animation: _countUpAnimation,
                            builder: (context, _) {
                              final currentPaise = widget.netPaise.abs();
                              final animatedPaise = (currentPaise * _countUpAnimation.value).round();
                              return Text(
                                CurrencyFormatter.formatPaise(
                                  animatedPaise,
                                  showSign: false,
                                  absolute: true,
                                ),
                                style: AppTypography.moneyHero.copyWith(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.2,
                                  color: theme.white, // Strictly white on navy!
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 18),

                          // Thin diverging proportional split bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2.5),
                            child: SizedBox(
                              height: 4,
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

                          // Two columns separated by a hairline:
                          // "Owed to you ₹X · from N people" and "You owe ₹Y · to M people"
                          IntrinsicHeight(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Owed to you',
                                        style: AppTypography.caption.copyWith(
                                          color: theme.white.withValues(alpha: 0.70),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        CurrencyFormatter.formatPaise(widget.totalOwedToUserPaise),
                                        style: AppTypography.titleMedium.copyWith(
                                          color: theme.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        'from ${widget.owedFromCount} ${widget.owedFromCount == 1 ? "person" : "people"}',
                                        style: AppTypography.caption.copyWith(
                                          color: theme.white.withValues(alpha: 0.65),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  margin: const EdgeInsets.symmetric(horizontal: 14),
                                  color: theme.white.withValues(alpha: 0.15),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'You owe',
                                        style: AppTypography.caption.copyWith(
                                          color: theme.white.withValues(alpha: 0.70),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        CurrencyFormatter.formatPaise(widget.totalUserOwesPaise),
                                        style: AppTypography.titleMedium.copyWith(
                                          color: theme.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        'to ${widget.owesToCount} ${widget.owesToCount == 1 ? "person" : "people"}',
                                        style: AppTypography.caption.copyWith(
                                          color: theme.white.withValues(alpha: 0.65),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Hairline divider above footer
                          Container(
                            height: 1,
                            color: theme.white.withValues(alpha: 0.12),
                          ),
                          const SizedBox(height: 14),

                          // Footer row: stack of up to 3 avatars (largest counterparties) and "View breakdown ›"
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (widget.counterparties.isNotEmpty)
                                SizedBox(
                                  height: 28,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (int i = 0; i < widget.counterparties.take(3).length; i++)
                                        Align(
                                          widthFactor: 0.75,
                                          child: PersonAvatar(
                                            person: widget.counterparties[i],
                                            size: 26,
                                          ),
                                        ),
                                    ],
                                  ),
                                )
                              else
                                const SizedBox.shrink(),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'View breakdown',
                                    style: AppTypography.caption.copyWith(
                                      color: theme.white.withValues(alpha: 0.85),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: theme.white.withValues(alpha: 0.85),
                                  ),
                                ],
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
    if (size.width == 0 || size.height == 0) return;

    // Base deep indigo-navy gradient
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          startColor,
          endColor,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), basePaint);

    // Faint violet corner glow top-right
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.85, -0.85),
        radius: 1.0,
        colors: [
          accentColor.withValues(alpha: 0.35),
          startColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);

    // Secondary subtle cyan/blue glow bottom-left
    final secondaryGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.85, 0.95),
        radius: 0.9,
        colors: [
          accentColor.withValues(alpha: 0.18),
          endColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), secondaryGlow);
  }

  @override
  bool shouldRepaint(covariant _HeroMeshPainter oldDelegate) {
    return oldDelegate.startColor != startColor ||
        oldDelegate.endColor != endColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isDark != isDark;
  }
}
