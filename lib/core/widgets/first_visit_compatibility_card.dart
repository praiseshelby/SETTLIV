import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../layout/adaptive_layout.dart';
import '../profile/experience_mode.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'gradient_primary_button.dart';

/// Triggered on narrow/touch viewports (compact web & phone app) once per
/// install, after the loading screen settles. Never shown on PC desktop web
/// or inside the PC phone frame.
class FirstVisitCompatibilityCard extends ConsumerStatefulWidget {
  const FirstVisitCompatibilityCard({super.key});

  static const String prefKey = 'settliv_first_visit_card_dismissed';

  @override
  ConsumerState<FirstVisitCompatibilityCard> createState() =>
      _FirstVisitCompatibilityCardState();
}

class _FirstVisitCompatibilityCardState
    extends ConsumerState<FirstVisitCompatibilityCard> {
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CompatibilityPreviewSheet.showIfNeeded(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class CompatibilityPreviewSheet extends StatelessWidget {
  final EffectiveExperience effectiveExperience;
  final bool isCompact;

  const CompatibilityPreviewSheet({
    super.key,
    required this.effectiveExperience,
    required this.isCompact,
  });

  static bool _hasShownThisSession = false;

  static Future<void> showIfNeeded(BuildContext context, WidgetRef ref) async {
    if (_hasShownThisSession) return;
    final profile = ref.read(deviceProfileProvider);
    final isCompact = AdaptiveLayout.isCompact(context);
    // Never show on PC desktop web or inside App-in-frame on PC
    if (profile.isDesktop || !isCompact) return;

    final prefs = ref.read(sharedPreferencesProvider);
    final dismissed =
        prefs?.getBool(FirstVisitCompatibilityCard.prefKey) ?? false;
    if (dismissed) return;

    _hasShownThisSession = true;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!context.mounted) return;

    final theme = context.settliv;
    final effective = ref.read(effectiveExperienceProvider);

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: theme.transparent,
      barrierColor: theme.scrim,
      builder: (ctx) => CompatibilityPreviewSheet(
        effectiveExperience: effective,
        isCompact: isCompact,
      ),
    );

    // Persist on any dismissal (Got it, View layouts, scrim tap, back)
    prefs?.setBool(FirstVisitCompatibilityCard.prefKey, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final currentTile = effectiveExperience == EffectiveExperience.app
        ? 2
        : (isCompact ? 1 : 0);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: theme.hairline)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.hairline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Compatibility preview',
                    style: AppTypography.titleLarge.copyWith(
                      color: theme.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This link shows every Settliv layout. The switch is for this preview only; each device gets its own layout in the shipped product.',
                    style: AppTypography.body.copyWith(
                      color: theme.muted,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniWireframeTile(
                          label: 'PC website',
                          kind: _WireframeKind.pcWeb,
                          isCurrent: currentTile == 0,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MiniWireframeTile(
                          label: 'Mobile web',
                          kind: _WireframeKind.mobileWeb,
                          isCurrent: currentTile == 1,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MiniWireframeTile(
                          label: 'Mobile app',
                          kind: _WireframeKind.mobileApp,
                          isCurrent: currentTile == 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: theme.hairline),
                              foregroundColor: theme.ink,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Got it'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: GradientPrimaryButton(
                            height: 48,
                            label: 'View layouts',
                            onPressed: () {
                              Navigator.of(context).pop();
                              context.push('/settings?section=experience');
                            },
                          ),
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
    );
  }
}

enum _WireframeKind { pcWeb, mobileWeb, mobileApp }

class _MiniWireframeTile extends StatelessWidget {
  final String label;
  final _WireframeKind kind;
  final bool isCurrent;

  const _MiniWireframeTile({
    required this.label,
    required this.kind,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrent
            ? theme.accent.withValues(alpha: theme.isDark ? 0.14 : 0.08)
            : theme.raised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? theme.accent : theme.hairline,
          width: isCurrent ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            child: SizedBox(
              width: 44,
              height: 30,
              child: CustomPaint(
                painter: _WireframePainter(
                  kind: kind,
                  strokeColor: isCurrent ? theme.accent : theme.muted,
                  fillColor: (isCurrent ? theme.accent : theme.muted)
                      .withValues(alpha: 0.14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: isCurrent ? theme.ink : theme.muted,
              fontSize: 11,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _WireframePainter extends CustomPainter {
  final _WireframeKind kind;
  final Color strokeColor;
  final Color fillColor;

  const _WireframePainter({
    required this.kind,
    required this.strokeColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final fill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    if (kind == _WireframeKind.pcWeb) {
      final outer = RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
        const Radius.circular(4),
      );
      canvas.drawRRect(outer, stroke);
      // Left sidebar
      canvas.drawRect(Rect.fromLTWH(4, 4, 10, size.height - 8), fill);
      // Hero block
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(17, 6, size.width - 23, 10),
          const Radius.circular(2),
        ),
        fill,
      );
    } else if (kind == _WireframeKind.mobileWeb) {
      final outer = RRect.fromRectAndRadius(
        Rect.fromLTWH(13, 1, 18, size.height - 2),
        const Radius.circular(4),
      );
      canvas.drawRRect(outer, stroke);
      // Top header bar
      canvas.drawRect(const Rect.fromLTWH(15, 3, 14, 4), fill);
      // Content block
      canvas.drawRect(const Rect.fromLTWH(15, 10, 14, 10), fill);
    } else {
      final outer = RRect.fromRectAndRadius(
        Rect.fromLTWH(13, 1, 18, size.height - 2),
        const Radius.circular(4),
      );
      canvas.drawRRect(outer, stroke);
      // Hero card
      canvas.drawRect(const Rect.fromLTWH(15, 4, 14, 9), fill);
      // Bottom docked bar
      canvas.drawRect(Rect.fromLTWH(15, size.height - 6, 14, 3), fill);
    }
  }

  @override
  bool shouldRepaint(covariant _WireframePainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.strokeColor != strokeColor;
}
