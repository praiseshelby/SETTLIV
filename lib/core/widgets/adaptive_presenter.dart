import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../layout/adaptive_layout.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../theme/motion_tokens.dart';
import 'glass_sheet_scaffold.dart';

enum PresentationType {
  formOrConfirmation,
  detailView,
}

class AdaptivePresenter {
  AdaptivePresenter._();

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    Widget? trailing,
    PresentationType type = PresentationType.formOrConfirmation,
    bool isScrollControlled = true,
    double maxWidth = 560,
  }) {
    final layoutClass = AdaptiveLayout.of(context);
    final theme = context.settliv;

    // Check effective experience
    // App experience or Compact Web -> bottom sheet
    if (layoutClass == LayoutClass.compact) {
      return showModalBottomSheet<T>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: isScrollControlled,
        backgroundColor: theme.transparent,
        barrierColor: theme.scrim,
        builder: (context) => GlassSheetScaffold(
          title: title,
          trailing: trailing,
          child: child,
        ),
      );
    }

    // Medium & Expanded Web:
    if (type == PresentationType.detailView) {
      // Right-side drawer (max 440)
      return showGeneralDialog<T>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: true,
        barrierLabel: 'Dismiss',
        barrierColor: theme.scrim,
        transitionDuration: MotionTokens.durationStandard,
        pageBuilder: (ctx, anim, secAnim) {
          return _AdaptiveDrawerContent(
            title: title,
            trailing: trailing,
            child: child,
          );
        },
        transitionBuilder: (ctx, anim, secAnim, childWidget) {
          final curved = CurvedAnimation(parent: anim, curve: MotionTokens.curveStandard);
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(curved),
            child: childWidget,
          );
        },
      );
    } else {
      // Centered dialog (max 560)
      return showGeneralDialog<T>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: true,
        barrierLabel: 'Dismiss',
        barrierColor: theme.scrim,
        transitionDuration: MotionTokens.durationStandard,
        pageBuilder: (ctx, anim, secAnim) {
          return _AdaptiveDialogContent(
            title: title,
            trailing: trailing,
            maxWidth: maxWidth,
            child: child,
          );
        },
        transitionBuilder: (ctx, anim, secAnim, childWidget) {
          final curved = CurvedAnimation(parent: anim, curve: MotionTokens.curveStandard);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
              child: childWidget,
            ),
          );
        },
      );
    }
  }
}

class _AdaptiveDialogContent extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final double maxWidth;
  final Widget child;

  const _AdaptiveDialogContent({
    required this.title,
    this.trailing,
    this.maxWidth = 560,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    return FocusScope(
      autofocus: true,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            Navigator.of(context).pop();
          },
        },
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Material(
              color: theme.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: theme.hairline),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadow.withValues(alpha: theme.isDark ? 0.45 : 0.15),
                          blurRadius: 36,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // 1px top highlight
                        Positioned(
                          top: 0,
                          left: 24,
                          right: 24,
                          height: 1,
                          child: Container(color: theme.innerHighlight),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: AppTypography.titleLarge.copyWith(
                                        color: theme.ink,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (trailing != null) trailing!,
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded),
                                    color: theme.muted,
                                    tooltip: 'Close (Esc)',
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Flexible(
                                child: SingleChildScrollView(
                                  child: child,
                                ),
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
        ),
      ),
    );
  }
}

class _AdaptiveDrawerContent extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;

  const _AdaptiveDrawerContent({
    required this.title,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    return FocusScope(
      autofocus: true,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            Navigator.of(context).pop();
          },
        },
        child: Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Material(
              color: theme.transparent,
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
                      border: Border(left: BorderSide(color: theme.hairline)),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadow.withValues(alpha: theme.isDark ? 0.45 : 0.15),
                          blurRadius: 36,
                          offset: const Offset(-8, 0),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          bottom: 0,
                          left: 0,
                          width: 1,
                          child: Container(color: theme.innerHighlight),
                        ),
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: AppTypography.titleLarge.copyWith(
                                          color: theme.ink,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (trailing != null) trailing!,
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded),
                                      color: theme.muted,
                                      tooltip: 'Close (Esc)',
                                      onPressed: () => Navigator.of(context).pop(),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: child,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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
