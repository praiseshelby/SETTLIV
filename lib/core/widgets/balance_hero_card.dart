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
  static bool hasSweptThisSession = false;

  @override
  State<BalanceHeroCard> createState() => _BalanceHeroCardState();
}

class _BalanceHeroCardState extends State<BalanceHeroCard>
    with TickerProviderStateMixin {
  late AnimationController _countUpController;
  late Animation<double> _countUpAnimation;
  late AnimationController _sweepController;
  late Animation<double> _sweepAnimation;
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

    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _sweepAnimation = CurvedAnimation(
      parent: _sweepController,
      curve: Curves.easeInOutCubic,
    );

    if (BalanceHeroCard.hasCountedUpThisSession) {
      _countUpController.value = 1.0;
    } else {
      BalanceHeroCard.hasCountedUpThisSession = true;
      _countUpController.forward().then((_) {
        if (!BalanceHeroCard.hasSweptThisSession && mounted) {
          BalanceHeroCard.hasSweptThisSession = true;
          _sweepController.forward();
        }
      });
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
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final isDark = theme.isDark;
    final primaryTextColor = isDark ? theme.white : theme.ink;
    final secondaryTextColor =
        isDark ? theme.white.withValues(alpha: 0.78) : theme.muted;
    final dividerColor =
        isDark ? theme.white.withValues(alpha: 0.14) : theme.hairline;
    final barEmerald = isDark ? theme.emerald : theme.textEmerald;
    final barCoral = isDark ? theme.coral : theme.textCoral;
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      _countUpController.value = 1.0;
      _sweepController.value = 0.0;
    }

    final String headlineSentence;
    Color? statusDotColor;
    if (widget.netPaise > 0) {
      headlineSentence = "You're owed";
      statusDotColor = theme.textEmerald;
    } else if (widget.netPaise < 0) {
      headlineSentence = "You owe";
      statusDotColor = theme.textCoral;
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
      label: 'Net position across groups. Tap to view breakdown.',
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
          scale: _isPressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: RepaintBoundary(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: theme.hairline,
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.cardAmbientShadow.withValues(alpha: isDark ? 0.40 : 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  children: [
                    // 1. Layered pearl-lavender (light) / navy (dark) mesh with contour arcs
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _HeroMeshTopographicPainter(
                          startColor: theme.heroMeshStart,
                          endColor: theme.heroMeshEnd,
                          accentColor: theme.heroMeshAccent,
                          whiteColor: theme.white,
                          isDark: isDark,
                        ),
                      ),
                    ),

                    // 2. 1px inner hairline top highlight
                    Positioned(
                      top: 0,
                      left: 12,
                      right: 12,
                      height: 1.0,
                      child: Container(
                        color: theme.innerHighlight.withValues(alpha: isDark ? 0.22 : 0.75),
                      ),
                    ),

                    // 3. Card Content (compact vertical sizing, total height <= 176px at 390w)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Eyebrow "NET POSITION" + Sentence + Status Dot
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'NET POSITION',
                                    style: AppTypography.eyebrow.copyWith(
                                      color: secondaryTextColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (statusDotColor != null) ...[
                                    const SizedBox(width: 6),
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
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  headlineSentence,
                                  style: AppTypography.caption.copyWith(
                                    color: primaryTextColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Big amount in Sora 38px with count-up, NO minus sign
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
                                  fontSize: 38,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.0,
                                  color: primaryTextColor,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),

                          // Thin diverging proportional split bar that animates in
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: SizedBox(
                              height: 3,
                              child: AnimatedBuilder(
                                animation: _countUpAnimation,
                                builder: (context, _) {
                                  final animRatio = owedRatio * _countUpAnimation.value + (1.0 - _countUpAnimation.value) * 0.5;
                                  return Row(
                                    children: [
                                      Flexible(
                                        flex: (animRatio * 100).round(),
                                        child: Container(
                                          color: barEmerald,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Flexible(
                                        flex: ((1.0 - animRatio) * 100).round(),
                                        child: Container(
                                          color: barCoral,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Two columns: "Owed to you ₹X · N people" / "You owe ₹Y · M people"
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  'Owed to you ${CurrencyFormatter.formatPaise(widget.totalOwedToUserPaise)} · ${widget.owedFromCount} ${widget.owedFromCount == 1 ? "person" : "people"}',
                                  style: AppTypography.caption.copyWith(
                                    color: secondaryTextColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    height: 1.25,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 14,
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                color: dividerColor,
                              ),
                              Expanded(
                                child: Text(
                                  'You owe ${CurrencyFormatter.formatPaise(widget.totalUserOwesPaise)} · ${widget.owesToCount} ${widget.owesToCount == 1 ? "person" : "people"}',
                                  style: AppTypography.caption.copyWith(
                                    color: secondaryTextColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    height: 1.25,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Hairline divider above footer
                          Container(
                            height: 1,
                            color: dividerColor,
                          ),
                          const SizedBox(height: 8),

                          // Footer row: counterparty avatars + "View breakdown ›"
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (widget.counterparties.isNotEmpty)
                                SizedBox(
                                  height: 24,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (int i = 0; i < widget.counterparties.take(3).length; i++)
                                        Align(
                                          widthFactor: 0.72,
                                          child: PersonAvatar(
                                            person: widget.counterparties[i],
                                            size: 24,
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
                                      color: primaryTextColor.withValues(alpha: 0.85),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: primaryTextColor.withValues(alpha: 0.85),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 4. Soft light sweep across the card (once per session)
                    AnimatedBuilder(
                      animation: _sweepAnimation,
                      builder: (context, _) {
                        if (_sweepAnimation.value <= 0.0 || _sweepAnimation.value >= 1.0) {
                          return const SizedBox.shrink();
                        }
                        return Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _LightSweepPainter(
                                progress: _sweepAnimation.value,
                                whiteColor: theme.white,
                              ),
                            ),
                          ),
                        );
                      },
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

class _HeroMeshTopographicPainter extends CustomPainter {
  final Color startColor;
  final Color endColor;
  final Color accentColor;
  final Color whiteColor;
  final bool isDark;

  const _HeroMeshTopographicPainter({
    required this.startColor,
    required this.endColor,
    required this.accentColor,
    required this.whiteColor,
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
          accentColor.withValues(alpha: isDark ? 0.28 : 0.16),
          startColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);

    // Faint topographic contour arcs on the right
    final arcPaint = Paint()
      ..color = isDark
          ? whiteColor.withValues(alpha: 0.04)
          : accentColor.withValues(alpha: 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width + 20, size.height / 2);
    for (int r = 40; r <= 160; r += 24) {
      canvas.drawCircle(center, r.toDouble(), arcPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeroMeshTopographicPainter oldDelegate) {
    return oldDelegate.startColor != startColor ||
        oldDelegate.endColor != endColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.whiteColor != whiteColor ||
        oldDelegate.isDark != isDark;
  }
}

class _LightSweepPainter extends CustomPainter {
  final double progress;
  final Color whiteColor;

  const _LightSweepPainter({
    required this.progress,
    required this.whiteColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Sweep line moves across from left to right
    final x = (size.width + 100) * progress - 50;
    final sweepPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          whiteColor.withOpacity(0.0),
          whiteColor.withOpacity(0.12),
          whiteColor.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(x - 40, 0, 80, size.height));

    canvas.drawRect(Rect.fromLTWH(x - 40, 0, 80, size.height), sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _LightSweepPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.whiteColor != whiteColor;
  }
}
