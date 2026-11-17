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
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
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
                  color: theme.tertiary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.titleLarge.copyWith(
                        color: theme.ink,
                      ),
                    ),
                  ),
                  ?trailing,
                  if (showCloseButton)
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: theme.secondary,
                        size: 22,
                      ),
                      onPressed: onClose ?? () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
