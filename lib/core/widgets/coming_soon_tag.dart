import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'sheet_scaffold.dart';
import 'primary_button.dart';

class ComingSoonTag extends StatelessWidget {
  final String label;
  final String? featureDescription;
  final VoidCallback? onTap;

  const ComingSoonTag({
    super.key,
    required this.label,
    this.featureDescription,
    this.onTap,
  });

  static void showComingSoonSheet(BuildContext context, String featureName,
      [String? details]) {
    SheetScaffold.show(
      context: context,
      isScrollControlled: false,
      builder: (ctx) {
        final theme = ctx.settliv;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.saffronTint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Coming in the full app',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.saffron,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                featureName,
                style: AppTypography.titleLarge.copyWith(
                  color: theme.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                details ??
                    'This feature is part of the Settliv native experience on Android & iOS. The prototype demonstrates core expense splitting, real-time balance resolution, and instant UPI settlement.',
                style: AppTypography.body.copyWith(
                  color: theme.secondary,
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Got it',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    return Semantics(
      button: true,
      label: '$label (Coming in full app)',
      child: InkWell(
        onTap: onTap ??
            () => showComingSoonSheet(context, label, featureDescription),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: theme.raised,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: theme.hairline, width: 1.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.saffron,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: theme.secondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
