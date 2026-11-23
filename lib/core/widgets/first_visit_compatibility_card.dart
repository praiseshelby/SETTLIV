import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../layout/adaptive_layout.dart';
import '../profile/experience_mode.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../theme/motion_tokens.dart';
import 'glass_surface.dart';

class FirstVisitCompatibilityCard extends ConsumerStatefulWidget {
  const FirstVisitCompatibilityCard({super.key});

  static const String prefKey = 'settliv_first_visit_card_dismissed';

  @override
  ConsumerState<FirstVisitCompatibilityCard> createState() =>
      _FirstVisitCompatibilityCardState();
}

class _FirstVisitCompatibilityCardState
    extends ConsumerState<FirstVisitCompatibilityCard>
    with SingleTickerProviderStateMixin {
  bool _dismissed = true;
  Timer? _autoFadeTimer;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: MotionTokens.durationStandard,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: MotionTokens.curveStandard,
    );

    _checkDismissed();
  }

  void _checkDismissed() {
    final prefs = ref.read(sharedPreferencesProvider);
    final isDismissed = prefs?.getBool(FirstVisitCompatibilityCard.prefKey) ?? false;
    if (!isDismissed) {
      setState(() => _dismissed = false);
      _animController.forward();
      // Auto-fades after 20 seconds
      _autoFadeTimer = Timer(const Duration(seconds: 20), () {
        _dismiss(remember: false);
      });
    }
  }

  void _dismiss({bool remember = true}) {
    if (!mounted || _dismissed) return;
    _autoFadeTimer?.cancel();
    _animController.reverse().then((_) {
      if (mounted) {
        setState(() => _dismissed = true);
      }
    });
    if (remember) {
      final prefs = ref.read(sharedPreferencesProvider);
      prefs?.setBool(FirstVisitCompatibilityCard.prefKey, true);
    }
  }

  @override
  void dispose() {
    _autoFadeTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final theme = context.settliv;
    final isCompact = AdaptiveLayout.isCompact(context);

    final cardContent = GlassSurface(
      level: GlassLevel.level3,
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Compatibility preview',
                        style: AppTypography.titleCard.copyWith(
                          color: theme.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Dismiss notice',
                child: InkWell(
                  onTap: () => _dismiss(remember: true),
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(Icons.close, size: 16, color: theme.muted),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This link shows all three Settliv layouts. The switch is for this preview only; in the shipped product each device gets just its own layout.',
            style: AppTypography.body.copyWith(
              color: theme.secondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => _dismiss(remember: true),
                  child: Text(
                    'Got it',
                    style: TextStyle(
                      fontFamily: AppTypography.fontBody,
                      color: theme.muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryButtonBg,
                    foregroundColor: theme.primaryButtonText,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    _dismiss(remember: true);
                    context.push('/settings?section=experience');
                  },
                  child: const Text(
                    'View layouts',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return FadeTransition(
      opacity: _fadeAnimation,
      child: isCompact
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              child: cardContent,
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: cardContent,
            ),
    );
  }
}
