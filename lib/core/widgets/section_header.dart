import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: AppTypography.sectionLabel.copyWith(
              color: theme.secondary,
              letterSpacing: 0.8,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
