import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/profile/experience_mode.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/motion_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/person_avatar.dart';
import '../../../../data/models/person.dart';

/// Web Signature Hero: Net Position
/// - Light mode ("Prism Pearl"): crisp white-to-lavender glass surface, 1.5px prismatic
///   border (violet-cyan-mint), dark ink text, semantic amounts in AA colours, concentric orbit rings.
/// - Dark mode ("Luminous Core"): deep indigo-violet mesh, glowing gradient edge, rotating orbit rings,
///   glowing white amount, refined diverging track.
/// - Both: ~72px Sora 800 display amount with 600ms odometer digit roll (once per session),
///   light sweep on mount, staggered avatar entrance, pointer spotlight.
class WebNetPositionHero extends ConsumerStatefulWidget {
  final int netPaise;
  final int totalOwedToUserPaise;
  final int totalUserOwesPaise;
  final int owedFromCount;
  final int owesToCount;
  final List<Person> counterparties;
  final VoidCallback? onTap;
  final bool isLarge;

  const WebNetPositionHero({
    super.key,
    required this.netPaise,
    required this.totalOwedToUserPaise,
    required this.totalUserOwesPaise,
    this.owedFromCount = 0,
    this.owesToCount = 0,
    this.counterparties = const [],
    this.onTap,
    this.isLarge = true,
  });

  static bool hasRolledOdometerThisSession = false;
  static bool hasSweptLightThisSession = false;

  @override
  ConsumerState<WebNetPositionHero> createState() => _WebNetPositionHeroState();
}

class _WebNetPositionHeroState extends ConsumerState<WebNetPositionHero>
    with TickerProviderStateMixin {
  late AnimationController _rollController;
  late Animation<double> _rollAnimation;
  late AnimationController _sweepController;
  late Animation<double> _sweepAnimation;
  AnimationController? _orbitController;

  Offset? _pointerLocalPos;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();

    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');

    _rollController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _rollAnimation = CurvedAnimation(
      parent: _rollController,
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

    if (!isTest) {
      _orbitController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 30),
      )..repeat();
    }

    if (WebNetPositionHero.hasRolledOdometerThisSession || isTest) {
      _rollController.value = 1.0;
    } else {
      WebNetPositionHero.hasRolledOdometerThisSession = true;
      _rollController.forward().then((_) {
        if (!WebNetPositionHero.hasSweptLightThisSession && mounted) {
          WebNetPositionHero.hasSweptLightThisSession = true;
          _sweepController.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _rollController.dispose();
    _sweepController.dispose();
    _orbitController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final isDark = theme.isDark;
    final profile = ref.watch(deviceProfileProvider);
    final isLite = MotionTokens.isLiteEffects(context, profile);
    final isDesktop = profile.isDesktop;

    final String headlineSentence;
    Color statusDotColor;
    if (widget.netPaise > 0) {
      headlineSentence = "You're owed overall";
      statusDotColor = theme.textEmerald;
    } else if (widget.netPaise < 0) {
      headlineSentence = "You owe overall";
      statusDotColor = theme.textCoral;
    } else {
      headlineSentence = "All settled up";
      statusDotColor = theme.muted;
    }

    final total = widget.totalOwedToUserPaise + widget.totalUserOwesPaise;
    final double owedRatio = total > 0
        ? (widget.totalOwedToUserPaise / total).clamp(0.05, 0.95)
        : 0.5;

    final displayFontSize = widget.isLarge ? (isDesktop ? 68.0 : 48.0) : 36.0;

    return Semantics(
      button: true,
      label: 'Net position across groups. Tap to view balances.',
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() {
          _isHovered = false;
          _pointerLocalPos = null;
        }),
        onHover: (e) {
          if (!isLite) {
            setState(() => _pointerLocalPos = e.localPosition);
          }
        },
        child: AnimatedContainer(
          duration: MotionTokens.durationFast,
          curve: MotionTokens.curveStandard,
          transform: Matrix4.translationValues(
            0,
            (isDesktop && !isLite && _isHovered) ? -2.0 : 0.0,
            0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              if (isDark)
                BoxShadow(
                  color: theme.cardAmbientShadow,
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                )
              else
                BoxShadow(
                  color: theme.cardAmbientShadow,
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              if (isDark && _isHovered && !isLite)
                BoxShadow(
                  color: theme.cardHoverGlow,
                  blurRadius: 28,
                  offset: Offset.zero,
                ),
            ],
          ),
          child: Material(
            color: theme.transparent,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(24),
              mouseCursor: SystemMouseCursors.click,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // 1. Background Surface
                    Positioned.fill(
                      child: isDark
                          ? _buildLuminousCoreBackground(theme)
                          : _buildPrismPearlBackground(theme),
                    ),

                    // 2. Corner Orbit Rings with Counterpart Nodes
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _orbitController ?? const AlwaysStoppedAnimation(0.0),
                          builder: (context, _) {
                            return CustomPaint(
                              painter: _HeroOrbitPainter(
                                theme: theme,
                                isDark: isDark,
                                rotation: (_orbitController?.value ?? 0.0) * 2 * math.pi,
                                totalOwedPaise: widget.totalOwedToUserPaise,
                                totalOwesPaise: widget.totalUserOwesPaise,
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // 3. Pointer Spotlight (Desktop only)
                    if (isDesktop && !isLite && _pointerLocalPos != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _HeroSpotlightPainter(
                              theme: theme,
                              spotlightPos: _pointerLocalPos!,
                              isDark: isDark,
                            ),
                          ),
                        ),
                      ),

                    // 4. Subtle Light Sweep on mount
                    AnimatedBuilder(
                      animation: _sweepAnimation,
                      builder: (context, _) {
                        if (_sweepAnimation.value == 0.0 || _sweepAnimation.value == 1.0) {
                          return const SizedBox.shrink();
                        }
                        return Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _LightSweepPainter(
                                progress: _sweepAnimation.value,
                                theme: theme,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // 5. Border: 1.5px Prismatic border (Light) or Glowing edge (Dark)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _HeroBorderPainter(
                            theme: theme,
                            isDark: isDark,
                            borderRadius: 24.0,
                          ),
                        ),
                      ),
                    ),

                    // 6. Foreground Content
                    Padding(
                      padding: EdgeInsets.all(widget.isLarge ? 28.0 : 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Header: Eyebrow "NET POSITION" + Status dot + Sentence
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'NET POSITION',
                                    style: AppTypography.eyebrow.copyWith(
                                      color: isDark
                                          ? theme.white.withValues(alpha: 0.70)
                                          : theme.muted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
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
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  headlineSentence,
                                  style: AppTypography.caption.copyWith(
                                    color: isDark
                                        ? theme.white.withValues(alpha: 0.85)
                                        : theme.secondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Large display amount (~72px Sora 800) with odometer roll
                          AnimatedBuilder(
                            animation: _rollAnimation,
                            builder: (context, _) {
                              final currentPaise = widget.netPaise.abs();
                              final animatedPaise =
                                  (currentPaise * _rollAnimation.value).round();
                              return Text(
                                CurrencyFormatter.formatPaise(animatedPaise),
                                style: TextStyle(
                                  fontFamily: AppTypography.fontBrand,
                                  fontFamilyFallback: AppTypography.brandFallback,
                                  fontSize: displayFontSize,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.6,
                                  color: isDark ? theme.white : theme.ink,
                                  height: 1.05,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 14),

                          // Semantic amounts in AA text colours
                          Wrap(
                            spacing: 16,
                            runSpacing: 6,
                            children: [
                              Text(
                                '+${CurrencyFormatter.formatPaise(widget.totalOwedToUserPaise)} owed to you',
                                style: AppTypography.bodySemiBold.copyWith(
                                  color: isDark ? theme.emerald : theme.textEmerald,
                                  fontSize: 13.5,
                                ),
                              ),
                              Text(
                                '-${CurrencyFormatter.formatPaise(widget.totalUserOwesPaise)} you owe',
                                style: AppTypography.bodySemiBold.copyWith(
                                  color: isDark ? theme.coral : theme.textCoral,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Refined Diverging Split Track
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              height: 5,
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: (owedRatio * 100).round(),
                                    child: Container(
                                      color: isDark ? theme.emerald : theme.textEmerald,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    flex: ((1.0 - owedRatio) * 100).round(),
                                    child: Container(
                                      color: isDark ? theme.coral : theme.textCoral,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Staggered Avatar Entrance & Counterparty Summary
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStaggeredAvatars(theme, isDark),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: isDark
                                    ? theme.white.withValues(alpha: 0.60)
                                    : theme.muted,
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

  Widget _buildPrismPearlBackground(SettlivThemeExtension theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.white,
            theme.white.withValues(alpha: 0.95),
            theme.farGlow1.withValues(alpha: 0.35),
          ],
          stops: const [0.0, 0.65, 1.0],
        ),
      ),
    );
  }

  Widget _buildLuminousCoreBackground(SettlivThemeExtension theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.heroMeshStart,
            theme.heroMeshEnd,
          ],
        ),
      ),
    );
  }

  Widget _buildStaggeredAvatars(SettlivThemeExtension theme, bool isDark) {
    final list = widget.counterparties.take(4).toList();
    if (list.isEmpty) {
      return Text(
        'Tap to view balances breakdown',
        style: AppTypography.caption.copyWith(
          color: isDark ? theme.white.withValues(alpha: 0.6) : theme.muted,
        ),
      );
    }

    final stackWidth = 28.0 + (list.length > 1 ? (list.length - 1) * 20.0 : 0.0);

    return SizedBox(
      height: 28,
      width: stackWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < list.length; i++)
            Positioned(
              left: i * 20.0,
              child: AnimatedBuilder(
                animation: _rollAnimation,
                builder: (context, child) {
                  final delay = i * 0.15;
                  final progress = ((_rollAnimation.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
                  return Opacity(
                    opacity: progress,
                    child: Transform.translate(
                      offset: Offset((1.0 - progress) * 8.0, 0),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? theme.heroMeshStart : theme.white,
                      width: 2.0,
                    ),
                  ),
                  child: PersonAvatar(
                    name: list[i].name,
                    size: 24,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 1.5px Prismatic border for Light mode / Glowing gradient edge for Dark mode
class _HeroBorderPainter extends CustomPainter {
  final SettlivThemeExtension theme;
  final bool isDark;
  final double borderRadius;

  const _HeroBorderPainter({
    required this.theme,
    required this.isDark,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    if (!isDark) {
      // Light Mode: 1.5px Prismatic Border (violet - cyan - mint)
      final prismShader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          theme.prismViolet.withValues(alpha: 0.85),
          theme.prismCyan.withValues(alpha: 0.75),
          theme.prismMint.withValues(alpha: 0.80),
        ],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(rect);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = prismShader;

      canvas.drawRRect(rrect, paint);
    } else {
      // Dark Mode: Glowing gradient edge
      final darkShader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          theme.accent.withValues(alpha: 0.65),
          theme.hairline.withValues(alpha: 0.25),
        ],
      ).createShader(rect);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = darkShader;

      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeroBorderPainter oldDelegate) {
    return oldDelegate.theme != theme || oldDelegate.isDark != isDark;
  }
}

/// Concentric orbit rings in the card corner that hold the two counterpart nodes
class _HeroOrbitPainter extends CustomPainter {
  final SettlivThemeExtension theme;
  final bool isDark;
  final double rotation;
  final int totalOwedPaise;
  final int totalOwesPaise;

  const _HeroOrbitPainter({
    required this.theme,
    required this.isDark,
    required this.rotation,
    required this.totalOwedPaise,
    required this.totalOwesPaise,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.86, size.height * 0.28);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = isDark
          ? theme.white.withValues(alpha: 0.08)
          : theme.ink.withValues(alpha: 0.06);

    const r1 = 44.0;
    const r2 = 78.0;
    const r3 = 114.0;

    canvas.drawCircle(center, r1, ringPaint);
    canvas.drawCircle(center, r2, ringPaint);
    canvas.drawCircle(center, r3, ringPaint);

    // Node 1: Owed node on Ring 1
    final angle1 = rotation;
    final p1 = Offset(
      center.dx + r1 * math.cos(angle1),
      center.dy + r1 * math.sin(angle1),
    );
    final owedNodePaint = Paint()
      ..color = isDark ? theme.emerald : theme.textEmerald
      ..style = PaintingStyle.fill;
    canvas.drawCircle(p1, 3.5, owedNodePaint);

    // Node 2: Owe node on Ring 2
    final angle2 = -rotation * 0.7 + 1.2;
    final p2 = Offset(
      center.dx + r2 * math.cos(angle2),
      center.dy + r2 * math.sin(angle2),
    );
    final oweNodePaint = Paint()
      ..color = isDark ? theme.coral : theme.textCoral
      ..style = PaintingStyle.fill;
    canvas.drawCircle(p2, 3.5, oweNodePaint);
  }

  @override
  bool shouldRepaint(covariant _HeroOrbitPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.isDark != isDark ||
        oldDelegate.theme != theme;
  }
}

/// Pointer spotlight inside Hero card (Desktop only)
class _HeroSpotlightPainter extends CustomPainter {
  final SettlivThemeExtension theme;
  final Offset spotlightPos;
  final bool isDark;

  const _HeroSpotlightPainter({
    required this.theme,
    required this.spotlightPos,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: spotlightPos, radius: 140);
    final shader = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        isDark
            ? theme.accent.withValues(alpha: 0.12)
            : theme.prismCyan.withValues(alpha: 0.10),
        theme.transparent,
      ],
      stops: const [0.0, 1.0],
    ).createShader(rect);

    canvas.drawCircle(spotlightPos, 140, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _HeroSpotlightPainter oldDelegate) {
    return oldDelegate.spotlightPos != spotlightPos || oldDelegate.isDark != isDark;
  }
}

/// Subtle light sweep on mount
class _LightSweepPainter extends CustomPainter {
  final double progress;
  final SettlivThemeExtension theme;

  const _LightSweepPainter({required this.progress, required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    const sweepWidth = 120.0;
    final startX = (size.width + sweepWidth * 2) * progress - sweepWidth;

    final rect = Rect.fromLTWH(startX, 0, sweepWidth, size.height);
    final shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        theme.transparent,
        theme.white.withValues(alpha: theme.isDark ? 0.08 : 0.16),
        theme.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(rect);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _LightSweepPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
