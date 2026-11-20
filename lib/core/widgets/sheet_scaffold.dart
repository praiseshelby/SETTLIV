import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class SheetScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final bool showCloseButton;
  final VoidCallback? onClose;

  const SheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.showCloseButton = true,
    this.onClose,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = true,
  }) {
    final theme = context.settliv;
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: isScrollControlled,
      backgroundColor: theme.transparent,
      barrierColor: theme.scrim,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: theme.hairline, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.hairline,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
              child: Row(
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
                  if (showCloseButton)
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: theme.muted),
                      onPressed: onClose ?? () => Navigator.of(context).pop(),
                      splashRadius: 20,
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.hairline),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
