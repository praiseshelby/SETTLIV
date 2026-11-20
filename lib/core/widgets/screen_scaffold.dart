import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'aurora_background.dart';

class ScreenScaffold extends StatelessWidget {
  final Widget? header;
  final Widget body;
  final Widget? floatingActionButton;
  final bool hasBottomBar;
  final EdgeInsets? padding;

  const ScreenScaffold({
    super.key,
    this.header,
    required this.body,
    this.floatingActionButton,
    this.hasBottomBar = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final mediaQuery = MediaQuery.of(context);
    final topSafeArea = mediaQuery.padding.top;
    final bottomSafeArea = mediaQuery.padding.bottom;

    // Bottom padding = bar height (~72) + safe area + 16px (when hasBottomBar is true)
    final bottomPadding = hasBottomBar
        ? (72.0 + bottomSafeArea + 16.0)
        : (bottomSafeArea + 24.0);

    return Scaffold(
      backgroundColor: theme.transparent,
      floatingActionButton: floatingActionButton,
      body: AuroraBackground(
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: EdgeInsets.only(
              top: topSafeArea + 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (header != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: header!,
                  ),
                  const SizedBox(height: 16.0),
                ],
                Expanded(
                  child: Padding(
                    padding: padding ?? EdgeInsets.only(bottom: bottomPadding),
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: body,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
