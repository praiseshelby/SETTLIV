import 'adaptive_presenter.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class GlassSheetScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final bool showHandle;

  const GlassSheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 24),
    this.showHandle = true,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    Widget? trailing,
    PresentationType type = PresentationType.formOrConfirmation,
    bool isScrollControlled = true,
  }) {
    return AdaptivePresenter.show<T>(
      context: context,
      title: title,
      trailing: trailing,
      type: type,
      isScrollControlled: isScrollControlled,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: theme.hairline,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.shadow.withValues(alpha: theme.isDark ? 0.45 : 0.12),
                  blurRadius: 32,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: padding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showHandle) ...[
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(top: 8, bottom: 16),
                          decoration: BoxDecoration(
                            color: theme.hairline,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: AppTypography.titleLarge.copyWith(
                            color: theme.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (trailing != null) trailing!,
                      ],
                    ),
                    const SizedBox(height: 16),
                    child,
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
