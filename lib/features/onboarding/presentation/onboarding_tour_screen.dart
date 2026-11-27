import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/layout/adaptive_layout.dart';
import '../../../core/profile/experience_mode.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/motion_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../data/repositories/in_memory_app_repository.dart';
import '../../activity/presentation/activity_screen.dart';
import '../../add_expense/presentation/add_expense_screen.dart';
import '../../group_detail/presentation/group_detail_screen.dart';
import '../../group_detail/sheets/settle_sheet.dart';
import '../../home/presentation/home_screen.dart';
import '../../insights/presentation/insights_screen.dart';
import '../domain/coach_card_placement.dart';
import '../domain/tour_scope.dart';

class _SandboxAuthStateNotifier extends AuthStateNotifier {
  @override
  AuthStatus build() => const AuthGuest();
}

class _SandboxAppStateNotifier extends AppStateNotifier {
  final InMemoryAppRepository _sandboxRepo;
  _SandboxAppStateNotifier(this._sandboxRepo);

  @override
  int build() {
    repository = _sandboxRepo;
    return 0;
  }
}

class _TourStop {
  final int stepNumber; // 1..6
  final String headline;
  final String line;
  final bool hasTryIt;

  const _TourStop({
    required this.stepNumber,
    required this.headline,
    required this.line,
    this.hasTryIt = false,
  });
}

class OnboardingTourScreen extends ConsumerStatefulWidget {
  const OnboardingTourScreen({super.key});

  @override
  ConsumerState<OnboardingTourScreen> createState() =>
      _OnboardingTourScreenState();
}

class _OnboardingTourScreenState extends ConsumerState<OnboardingTourScreen> {
  static const int _totalSteps = 6;
  static const int _maxStopIndex = 9;

  late final InMemoryAppRepository _sandbox;
  late final FocusNode _focusNode;
  final GlobalKey _stageKey = GlobalKey();
  final GlobalKey _homeHeroKey = GlobalKey();
  final GlobalKey _homeAttentionKey = GlobalKey();
  final GlobalKey _addQuickInputKey = GlobalKey();
  final GlobalKey _addSplitModesKey = GlobalKey();
  final GlobalKey _groupBalancesKey = GlobalKey();
  final GlobalKey _groupSettleKey = GlobalKey();
  final GlobalKey _recordsEntryKey = GlobalKey();
  final GlobalKey _insightsBudgetKey = GlobalKey();
  final TourAddController _addController = TourAddController();

  // Sub-stops:
  // 0: Step 1 Intro (Home dimmed)
  // 1: Step 2a Home Hero
  // 2: Step 2b Home Attention
  // 3: Step 3a Add Quick (Try it)
  // 4: Step 3b Add Manual Split Modes
  // 5: Step 4a Group Balances (group_goa)
  // 6: Step 4b Group Settle (Try it -> SettleSheet Demo)
  // 7: Step 5a Records
  // 8: Step 5b Insights
  // 9: Step 6 Finish
  int _stopIndex = 0;
  bool _isTransitioning = false;
  bool _isCompleting = false;
  bool _isExiting = false;
  bool _showGuestEndSheet = false;
  bool _isTypingTryIt = false;
  Timer? _typingTimer;
  Rect? _measuredTargetRect;
  Size _measuredCardSize = const Size(300, 175);
  CoachPlacementSide? _previousSide;

  @override
  void initState() {
    super.initState();
    _sandbox = InMemoryAppRepository();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTarget());
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isGuestTour => ref.read(authStateProvider) is AuthGuest;

  String _greetingHeadline() {
    final auth = ref.read(authStateProvider);
    if (auth is AuthSignedIn) {
      final first = auth.user.displayName.trim().split(' ').first;
      if (first.isNotEmpty) return 'Hi $first.';
    }
    return 'Hi there.';
  }

  _TourStop _stopFor(int index) {
    switch (index) {
      case 0:
        return _TourStop(
          stepNumber: 1,
          headline: _greetingHeadline(),
          line: 'A quick look around, under a minute.',
        );
      case 1:
        return const _TourStop(
          stepNumber: 2,
          headline: 'Your whole position, one number.',
          line: "What you're owed and what you owe, across every group.",
        );
      case 2:
        return const _TourStop(
          stepNumber: 2,
          headline: 'Only what needs you.',
          line: 'Overdue and unsettled items surface here.',
        );
      case 3:
        return const _TourStop(
          stepNumber: 3,
          headline: 'Type it like you say it.',
          line: 'Quick parses amount, people and split.',
          hasTryIt: true,
        );
      case 4:
        return const _TourStop(
          stepNumber: 3,
          headline: 'Or split exactly.',
          line: 'Equal, exact, percent, shares or by income.',
        );
      case 5:
        return const _TourStop(
          stepNumber: 4,
          headline: 'Exact, always.',
          line: 'Every split adds up to the paisa.',
        );
      case 6:
        return const _TourStop(
          stepNumber: 4,
          headline: 'Settle in your UPI app.',
          line: 'You confirm after paying. Partial and cash work too.',
          hasTryIt: true,
        );
      case 7:
        return const _TourStop(
          stepNumber: 5,
          headline: 'Nothing is final.',
          line: 'Every change is logged. Undo any delete.',
        );
      case 8:
        return const _TourStop(
          stepNumber: 5,
          headline: 'Where it went.',
          line: 'Monthly budget and category limits.',
        );
      case 9:
      default:
        return const _TourStop(
          stepNumber: 6,
          headline: 'Your account is empty and ready.',
          line: 'Add your first expense or head straight to Home.',
        );
    }
  }

  GlobalKey? _keyForStop(int index) {
    switch (index) {
      case 1:
        return _homeHeroKey;
      case 2:
        return _homeAttentionKey;
      case 3:
        return _addQuickInputKey;
      case 4:
        return _addSplitModesKey;
      case 5:
        return _groupBalancesKey;
      case 6:
        return _groupSettleKey;
      case 7:
        return _recordsEntryKey;
      case 8:
        return _insightsBudgetKey;
      default:
        return null;
    }
  }

  void _measureTarget() {
    if (!mounted) return;
    final targetKey = _keyForStop(_stopIndex);
    final stageBox =
        _stageKey.currentContext?.findRenderObject() as RenderBox?;
    if (targetKey == null || stageBox == null || !stageBox.hasSize) {
      if (_measuredTargetRect != null) {
        setState(() => _measuredTargetRect = null);
      }
      return;
    }
    final targetBox =
        targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (targetBox == null || !targetBox.hasSize) {
      if (_measuredTargetRect != null) {
        setState(() => _measuredTargetRect = null);
      }
      return;
    }
    final topLeft = targetBox.localToGlobal(Offset.zero, ancestor: stageBox);
    final nextRect = topLeft & targetBox.size;
    if (_measuredTargetRect != nextRect) {
      setState(() => _measuredTargetRect = nextRect);
    }
  }

  void _goToStop(int nextIndex) {
    if (_isCompleting || _isTransitioning) return;
    if (nextIndex < 0 || nextIndex > _maxStopIndex || nextIndex == _stopIndex) {
      return;
    }
    _typingTimer?.cancel();
    _isTypingTryIt = false;
    setState(() {
      _isTransitioning = true;
      _stopIndex = nextIndex;
    });
    if (nextIndex == 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _addController.setTab?.call(0);
      });
    } else if (nextIndex == 4) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _addController.setTab?.call(1);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTarget());
    Future<void>.delayed(const Duration(milliseconds: 140), () {
      if (mounted) {
        setState(() => _isTransitioning = false);
      }
    });
  }

  void _nextStop() {
    if (_stopIndex >= _maxStopIndex) {
      _completeTour(destination: '/', isSkip: false);
    } else if (_stopIndex == 1 && _homeAttentionKey.currentContext == null) {
      _goToStop(3);
    } else {
      _goToStop(_stopIndex + 1);
    }
  }

  void _prevStop() {
    if (_showGuestEndSheet) {
      _completeTour(destination: '/', isSkip: true);
      return;
    }
    if (_stopIndex <= 0) return;
    if (_stopIndex == 3 && _homeAttentionKey.currentContext == null) {
      _goToStop(1);
    } else {
      _goToStop(_stopIndex - 1);
    }
  }

  void _runTryIt() {
    if (_stopIndex == 6) {
      final goa = _sandbox.getGroup('group_goa');
      final stageCtx = _groupSettleKey.currentContext;
      if (goa != null && stageCtx != null) {
        SettleSheet.show(context: stageCtx, group: goa);
      }
      return;
    }
    if (_isTypingTryIt) return;
    const sample = 'Dinner 2400 with Aman and Riya';
    setState(() => _isTypingTryIt = true);
    _addController.setTab?.call(0);
    _addController.setQuickText?.call('');
    int i = 0;
    _typingTimer?.cancel();
    _typingTimer = Timer.periodic(const Duration(milliseconds: 35), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      i++;
      if (i > sample.length) {
        timer.cancel();
        if (mounted) setState(() => _isTypingTryIt = false);
        return;
      }
      _addController.setQuickText?.call(sample.substring(0, i));
    });
  }

  Future<void> _completeTour({
    required String destination,
    required bool isSkip,
  }) async {
    if (_isCompleting) return;
    if (!isSkip && _isGuestTour && !_showGuestEndSheet) {
      setState(() => _showGuestEndSheet = true);
      return;
    }
    _typingTimer?.cancel();
    setState(() {
      _isCompleting = true;
      _isExiting = true;
    });
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    if (!disableAnimations) {
      await Future<void>.delayed(
        Duration(milliseconds: isSkip ? 300 : 500),
      );
    }
    if (!mounted) return;
    await ref.read(onboardingPendingProvider.notifier).completeOnboarding();
    if (mounted) {
      context.go(destination);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_showGuestEndSheet) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _completeTour(destination: '/', isSkip: true);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _nextStop();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _prevStop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildSandboxScreen() {
    switch (_stopIndex) {
      case 3:
      case 4:
        return const AddExpenseScreen(initialTabIndex: 0);
      case 5:
      case 6:
        return const GroupDetailScreen(groupId: 'group_goa');
      case 7:
        return const ActivityScreen();
      case 8:
        return const InsightsScreen();
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final media = MediaQuery.of(context);
    final profile = ref.watch(deviceProfileProvider);
    final isLite = MotionTokens.isLiteEffects(context, profile);
    final disableAnimations = media.disableAnimations;
    final layoutClass = AdaptiveLayout.of(context);
    final effectiveExp = ref.watch(effectiveExperienceProvider);
    final isExpandedWeb =
        effectiveExp == EffectiveExperience.web &&
        layoutClass == LayoutClass.expanded;

    final stop = _stopFor(_stopIndex);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _prevStop();
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            if (_showGuestEndSheet) return;
            final v = details.primaryVelocity ?? 0;
            if (v < -250) {
              _nextStop();
            } else if (v > 250) {
              _prevStop();
            }
          },
          child: ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(null),
              authStateProvider.overrideWith(_SandboxAuthStateNotifier.new),
              appStateProvider.overrideWith(
                () => _SandboxAppStateNotifier(_sandbox),
              ),
            ],
            child: TourScope(
              homeHeroKey: _homeHeroKey,
              homeAttentionKey: _homeAttentionKey,
              addQuickInputKey: _addQuickInputKey,
              addSplitModesKey: _addSplitModesKey,
              groupBalancesKey: _groupBalancesKey,
              groupSettleKey: _groupSettleKey,
              recordsEntryKey: _recordsEntryKey,
              insightsBudgetKey: _insightsBudgetKey,
              addController: _addController,
              onInterceptRoute: (_) {},
              child: Scaffold(
                backgroundColor: theme.transparent,
                body: AnimatedOpacity(
                  duration: disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 300),
                  opacity: _isExiting ? 0.0 : 1.0,
                  child: LayoutBuilder(
                    key: _stageKey,
                    builder: (context, constraints) {
                      WidgetsBinding.instance
                          .addPostFrameCallback((_) => _measureTarget());
                      final viewport = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      final cardWidth =
                          CoachCardPlacementSolver.preferredCardWidth(
                        viewportWidth: viewport.width,
                        isExpandedWeb: isExpandedWeb,
                      );
                      final safePadding = EdgeInsets.only(
                        top: media.padding.top,
                        left: media.padding.left,
                        right: media.padding.right,
                        bottom: math.max(
                          media.padding.bottom,
                          media.viewInsets.bottom,
                        ),
                      );
                      final targetRect =
                          (_stopIndex >= 1 && _stopIndex <= 8)
                              ? _measuredTargetRect
                              : null;
                      final placement = CoachCardPlacementSolver.compute(
                        targetRect: targetRect,
                        viewportSize: viewport,
                        safePadding: safePadding,
                        cardSize: Size(cardWidth, _measuredCardSize.height),
                        isExpandedWeb: isExpandedWeb,
                        bottomReserved:
                            effectiveExp == EffectiveExperience.app
                                ? 72.0
                                : 0.0,
                        leftReserved: 0.0,
                      );
                      final sideFlipped = _previousSide != null &&
                          _previousSide != placement.side;
                      _previousSide = placement.side;

                      final moveDuration = disableAnimations
                          ? Duration.zero
                          : const Duration(milliseconds: 280);

                      return Stack(
                        children: [
                          Positioned.fill(child: _buildSandboxScreen()),
                          Positioned.fill(
                            child: _SpotlightOverlay(
                              targetRect: targetRect,
                              scrimColor: theme.ink.withValues(alpha: 0.58),
                              ringColor: theme.accent,
                              disableAnimations: disableAnimations,
                            ),
                          ),
                          if (!_showGuestEndSheet)
                            AnimatedPositioned(
                              duration: moveDuration,
                              curve: Curves.easeInOutCubic,
                              left: placement.cardRect.left,
                              top: placement.cardRect.top,
                              width: placement.cardRect.width,
                              child: _MeasureSize(
                                onChange: (size) {
                                  if ((size.height - _measuredCardSize.height)
                                              .abs() >
                                          1.0 ||
                                      (size.width - _measuredCardSize.width)
                                              .abs() >
                                          1.0) {
                                    setState(() => _measuredCardSize = size);
                                  }
                                },
                                child: AnimatedSwitcher(
                                  duration: disableAnimations
                                      ? Duration.zero
                                      : const Duration(milliseconds: 220),
                                  transitionBuilder: (child, anim) {
                                    if (disableAnimations || sideFlipped) {
                                      return FadeTransition(
                                        opacity: anim,
                                        child: child,
                                      );
                                    }
                                    final slide = Tween<Offset>(
                                      begin: Offset(
                                        placement.travelDirection.dx / 120.0,
                                        placement.travelDirection.dy / 120.0,
                                      ),
                                      end: Offset.zero,
                                    ).animate(
                                      CurvedAnimation(
                                        parent: anim,
                                        curve: Curves.easeOutCubic,
                                      ),
                                    );
                                    return FadeTransition(
                                      opacity: anim,
                                      child: SlideTransition(
                                        position: slide,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _CoachCalloutCard(
                                    key: ValueKey(_stopIndex),
                                    theme: theme,
                                    isLite: isLite,
                                    side: placement.side,
                                    notchOffset: placement.notchOffset,
                                    stepNumber: stop.stepNumber,
                                    totalSteps: _totalSteps,
                                    headline: stop.headline,
                                    line: stop.line,
                                    isCompleting: _isCompleting,
                                    isTransitioning: _isTransitioning,
                                    onBack: _stopIndex > 0 ? _prevStop : null,
                                    onNext: _nextStop,
                                    onSkip: () => _completeTour(
                                      destination: '/',
                                      isSkip: true,
                                    ),
                                    onTryIt:
                                        stop.hasTryIt ? _runTryIt : null,
                                    isTypingTryIt: _isTypingTryIt,
                                    isFinalSignedUp:
                                        _stopIndex == _maxStopIndex &&
                                            !_isGuestTour,
                                    onAddFirstExpense: () => _completeTour(
                                      destination: '/add',
                                      isSkip: false,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (_showGuestEndSheet)
                            Positioned.fill(
                              child: _GuestEndSheet(
                                theme: theme,
                                isLite: isLite,
                                disableAnimations: disableAnimations,
                                isAppLayout:
                                    effectiveExp == EffectiveExperience.app,
                                isCompleting: _isCompleting,
                                onCreateAccount: () async {
                                  if (_isCompleting) return;
                                  setState(() => _isCompleting = true);
                                  await ref
                                      .read(onboardingPendingProvider.notifier)
                                      .completeOnboarding();
                                  await ref
                                      .read(authStateProvider.notifier)
                                      .exitGuestMode();
                                  if (context.mounted) context.go('/signup');
                                },
                                onSignIn: () async {
                                  if (_isCompleting) return;
                                  setState(() => _isCompleting = true);
                                  await ref
                                      .read(onboardingPendingProvider.notifier)
                                      .completeOnboarding();
                                  await ref
                                      .read(authStateProvider.notifier)
                                      .exitGuestMode();
                                  if (context.mounted) context.go('/signin');
                                },
                                onContinueExploring: () => _completeTour(
                                  destination: '/',
                                  isSkip: true,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuestEndSheet extends StatelessWidget {
  final SettlivThemeExtension theme;
  final bool isLite;
  final bool disableAnimations;
  final bool isAppLayout;
  final bool isCompleting;
  final VoidCallback onCreateAccount;
  final VoidCallback onSignIn;
  final VoidCallback onContinueExploring;

  const _GuestEndSheet({
    required this.theme,
    required this.isLite,
    required this.disableAnimations,
    required this.isAppLayout,
    required this.isCompleting,
    required this.onCreateAccount,
    required this.onSignIn,
    required this.onContinueExploring,
  });

  @override
  Widget build(BuildContext context) {
    final card = GlassSurface(
      level: GlassLevel.level2,
      borderRadius: 24,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: RepaintBoundary(
              child: SizedBox(
                width: 56,
                height: 56,
                child: CustomPaint(
                  painter: SettleOrbitMotifPainter(
                    ringColor: theme.hairline,
                    accentColor: theme.accent,
                    emeraldColor: theme.emerald,
                    coralColor: theme.coral,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Keep what you build.',
            textAlign: TextAlign.center,
            style: AppTypography.titleLarge.copyWith(color: theme.ink),
          ),
          const SizedBox(height: 6),
          Text(
            'Create an account to save your data and use it on any device.',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              color: theme.muted,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryButtonBg,
                foregroundColor: theme.primaryButtonText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: isCompleting ? null : onCreateAccount,
              child: const Text(
                'Create account',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.ink,
                side: BorderSide(color: theme.hairline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: isCompleting ? null : onSignIn,
              child: const Text(
                'Sign in',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 48,
            child: TextButton(
              onPressed: isCompleting ? null : onContinueExploring,
              child: Text(
                'Continue exploring',
                style: AppTypography.bodySemiBold.copyWith(color: theme.muted),
              ),
            ),
          ),
        ],
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        final dy = disableAnimations ? 0.0 : (1.0 - t) * 12.0;
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, dy), child: child),
        );
      },
      child: Align(
        alignment: isAppLayout ? Alignment.bottomCenter : Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: card,
          ),
        ),
      ),
    );
  }
}

class _SpotlightOverlay extends StatelessWidget {
  final Rect? targetRect;
  final Color scrimColor;
  final Color ringColor;
  final bool disableAnimations;

  const _SpotlightOverlay({
    required this.targetRect,
    required this.scrimColor,
    required this.ringColor,
    required this.disableAnimations,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Rect?>(
      tween: RectTween(begin: targetRect, end: targetRect),
      duration: disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
      builder: (context, animatedRect, _) {
        final cutout = animatedRect?.inflate(8.0);
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _SpotlightScrimPainter(
                      targetRect: cutout,
                      scrimColor: scrimColor,
                      ringColor: ringColor,
                    ),
                  ),
                ),
              ),
            ),
            if (cutout == null)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                ),
              )
            else ...[
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: math.max(0.0, cutout.top),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: math.max(0.0, cutout.bottom),
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                ),
              ),
              Positioned(
                left: 0,
                width: math.max(0.0, cutout.left),
                top: math.max(0.0, cutout.top),
                height: math.max(0.0, cutout.height),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                ),
              ),
              Positioned(
                left: math.max(0.0, cutout.right),
                right: 0,
                top: math.max(0.0, cutout.top),
                height: math.max(0.0, cutout.height),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SpotlightScrimPainter extends CustomPainter {
  final Rect? targetRect;
  final Color scrimColor;
  final Color ringColor;

  const _SpotlightScrimPainter({
    required this.targetRect,
    required this.scrimColor,
    required this.ringColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    if (targetRect == null) {
      canvas.drawPath(full, Paint()..color = scrimColor);
      return;
    }
    final rrect = RRect.fromRectAndRadius(targetRect!, const Radius.circular(22));
    final cutout = Path()..addRRect(rrect);
    final combined = Path.combine(PathOperation.difference, full, cutout);
    canvas.drawPath(combined, Paint()..color = scrimColor);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = ringColor.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightScrimPainter oldDelegate) =>
      targetRect != oldDelegate.targetRect ||
      scrimColor != oldDelegate.scrimColor ||
      ringColor != oldDelegate.ringColor;
}

class _CoachCalloutCard extends StatelessWidget {
  final SettlivThemeExtension theme;
  final bool isLite;
  final CoachPlacementSide side;
  final double notchOffset;
  final int stepNumber;
  final int totalSteps;
  final String headline;
  final String line;
  final bool isCompleting;
  final bool isTransitioning;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback? onTryIt;
  final bool isTypingTryIt;
  final bool isFinalSignedUp;
  final VoidCallback? onAddFirstExpense;

  const _CoachCalloutCard({
    super.key,
    required this.theme,
    required this.isLite,
    required this.side,
    required this.notchOffset,
    required this.stepNumber,
    required this.totalSteps,
    required this.headline,
    required this.line,
    required this.isCompleting,
    required this.isTransitioning,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
    this.onTryIt,
    this.isTypingTryIt = false,
    this.isFinalSignedUp = false,
    this.onAddFirstExpense,
  });

  @override
  Widget build(BuildContext context) {
    final shape = _CoachNotchShape(
      side: side,
      notchOffset: notchOffset,
      radius: 20,
    );
    final isFirst = stepNumber == 1 && onBack == null;
    final isLast = stepNumber == totalSteps;
    final progress = stepNumber / totalSteps;

    final EdgeInsets notchPad = switch (side) {
      CoachPlacementSide.below => const EdgeInsets.only(top: 10),
      CoachPlacementSide.above => const EdgeInsets.only(bottom: 10),
      CoachPlacementSide.right => const EdgeInsets.only(left: 10),
      CoachPlacementSide.left => const EdgeInsets.only(right: 10),
      CoachPlacementSide.overlay => EdgeInsets.zero,
    };

    Widget surface = Container(
      decoration: ShapeDecoration(
        color: theme.surface.withValues(alpha: isLite ? 0.96 : 0.88),
        shape: shape,
        shadows: [
          BoxShadow(
            color: theme.shadow.withValues(alpha: theme.isDark ? 0.42 : 0.14),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: notchPad,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 2.5,
                backgroundColor: theme.hairline,
                valueColor: AlwaysStoppedAnimation<Color>(theme.accent),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$stepNumber / $totalSteps',
                        style: AppTypography.caption.copyWith(
                          color: theme.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton(
                        onPressed: isCompleting ? null : onSkip,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          tapTargetSize: MaterialTapTargetSize.padded,
                        ),
                        child: Text(
                          'Skip',
                          style: AppTypography.caption.copyWith(
                            color: theme.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    headline,
                    style: AppTypography.sectionTitle.copyWith(color: theme.ink),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    line,
                    style: AppTypography.body.copyWith(
                      color: theme.muted,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (isFinalSignedUp) ...[
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.ink,
                                side: BorderSide(color: theme.hairline),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: isCompleting ? null : onNext,
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Go to Home'),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primaryButtonBg,
                                foregroundColor: theme.primaryButtonText,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              onPressed:
                                  isCompleting ? null : onAddFirstExpense,
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Add first expense',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Row(
                      children: [
                        if (onBack != null)
                          TextButton(
                            onPressed: (isCompleting || isTransitioning)
                                ? null
                                : onBack,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              tapTargetSize: MaterialTapTargetSize.padded,
                            ),
                            child: Text(
                              'Back',
                              style: AppTypography.bodySemiBold.copyWith(
                                color: theme.muted,
                              ),
                            ),
                          ),
                        if (onTryIt != null)
                          TextButton(
                            onPressed: isTypingTryIt ? null : onTryIt,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              tapTargetSize: MaterialTapTargetSize.padded,
                            ),
                            child: Text(
                              isTypingTryIt ? 'Typing...' : 'Try it',
                              style: AppTypography.bodySemiBold.copyWith(
                                color: theme.accent,
                              ),
                            ),
                          ),
                        const Spacer(),
                        TextButton(
                          onPressed:
                              (isCompleting || isTransitioning) ? null : onNext,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            tapTargetSize: MaterialTapTargetSize.padded,
                            foregroundColor: theme.accent,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isLast ? 'Finish' : (isFirst ? 'Start' : 'Next'),
                                style: AppTypography.bodySemiBold.copyWith(
                                  color: theme.accent,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: theme.accent,
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
    );

    if (!isLite) {
      surface = ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: surface,
        ),
      );
    }

    return CustomPaint(
      foregroundPainter: _CoachNotchBorderPainter(
        shape: shape,
        borderColor: theme.hairline,
      ),
      child: surface,
    );
  }
}

class _CoachNotchBorderPainter extends CustomPainter {
  final ShapeBorder shape;
  final Color borderColor;

  const _CoachNotchBorderPainter({
    required this.shape,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = shape.getOuterPath(Offset.zero & size);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = borderColor,
    );
  }

  @override
  bool shouldRepaint(covariant _CoachNotchBorderPainter oldDelegate) =>
      shape != oldDelegate.shape || borderColor != oldDelegate.borderColor;
}

class _CoachNotchShape extends ShapeBorder {
  final CoachPlacementSide side;
  final double notchOffset;
  final double radius;
  static const double notchSize = 10.0;

  const _CoachNotchShape({
    required this.side,
    required this.notchOffset,
    required this.radius,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final bodyRect = switch (side) {
      CoachPlacementSide.below =>
        Rect.fromLTRB(rect.left, rect.top + notchSize, rect.right, rect.bottom),
      CoachPlacementSide.above =>
        Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom - notchSize),
      CoachPlacementSide.right =>
        Rect.fromLTRB(rect.left + notchSize, rect.top, rect.right, rect.bottom),
      CoachPlacementSide.left =>
        Rect.fromLTRB(rect.left, rect.top, rect.right - notchSize, rect.bottom),
      CoachPlacementSide.overlay => rect,
    };

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(bodyRect, Radius.circular(radius)));

    if (side == CoachPlacementSide.overlay) {
      return path;
    }

    const half = 8.0;
    final notch = Path();
    switch (side) {
      case CoachPlacementSide.below:
        final cx = (rect.left + notchOffset).clamp(
          bodyRect.left + radius + half,
          bodyRect.right - radius - half,
        ).toDouble();
        notch
          ..moveTo(cx - half, bodyRect.top + 1)
          ..quadraticBezierTo(cx, rect.top - 2, cx + half, bodyRect.top + 1)
          ..close();
      case CoachPlacementSide.above:
        final cx = (rect.left + notchOffset).clamp(
          bodyRect.left + radius + half,
          bodyRect.right - radius - half,
        ).toDouble();
        notch
          ..moveTo(cx - half, bodyRect.bottom - 1)
          ..quadraticBezierTo(cx, rect.bottom + 2, cx + half, bodyRect.bottom - 1)
          ..close();
      case CoachPlacementSide.right:
        final cy = (rect.top + notchOffset).clamp(
          bodyRect.top + radius + half,
          bodyRect.bottom - radius - half,
        ).toDouble();
        notch
          ..moveTo(bodyRect.left + 1, cy - half)
          ..quadraticBezierTo(rect.left - 2, cy, bodyRect.left + 1, cy + half)
          ..close();
      case CoachPlacementSide.left:
        final cy = (rect.top + notchOffset).clamp(
          bodyRect.top + radius + half,
          bodyRect.bottom - radius - half,
        ).toDouble();
        notch
          ..moveTo(bodyRect.right - 1, cy - half)
          ..quadraticBezierTo(rect.right + 2, cy, bodyRect.right - 1, cy + half)
          ..close();
      case CoachPlacementSide.overlay:
        break;
    }

    return Path.combine(PathOperation.union, path, notch);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => _CoachNotchShape(
        side: side,
        notchOffset: notchOffset * t,
        radius: radius * t,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CoachNotchShape &&
          side == other.side &&
          notchOffset == other.notchOffset &&
          radius == other.radius;

  @override
  int get hashCode => Object.hash(side, notchOffset, radius);
}

class _MeasureSize extends StatefulWidget {
  final ValueChanged<Size> onChange;
  final Widget child;

  const _MeasureSize({required this.onChange, required this.child});

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  Size? _lastSize;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ro = context.findRenderObject() as RenderBox?;
      if (ro == null || !ro.hasSize) return;
      if (_lastSize != ro.size) {
        _lastSize = ro.size;
        widget.onChange(ro.size);
      }
    });
    return widget.child;
  }
}
