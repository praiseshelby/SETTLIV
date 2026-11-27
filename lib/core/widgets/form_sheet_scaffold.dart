import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared form sheet container with a scrollable body and a sticky bottom
/// action bar that remains visible and tappable above keyboard insets and
/// safe areas at narrow phone sizes.
class FormSheetScaffold extends StatelessWidget {
  final Widget body;
  final Widget bottomBar;
  final EdgeInsetsGeometry bodyPadding;
  final EdgeInsetsGeometry bottomPadding;

  const FormSheetScaffold({
    super.key,
    required this.body,
    required this.bottomBar,
    this.bodyPadding = const EdgeInsets.fromLTRB(20, 8, 20, 16),
    this.bottomPadding = const EdgeInsets.fromLTRB(20, 12, 20, 16),
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final media = MediaQuery.of(context);
    final availableHeight = math.max(
      200.0,
      media.size.height - media.viewInsets.bottom - media.padding.top - 110.0,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: availableHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: bodyPadding,
                child: body,
              ),
            ),
            Divider(height: 1, color: theme.hairline),
            SafeArea(
              top: false,
              child: Padding(
                padding: bottomPadding,
                child: bottomBar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
