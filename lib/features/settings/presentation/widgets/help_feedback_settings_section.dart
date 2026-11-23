import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../data/models/feedback_report.dart';
import '../../../../data/repositories/in_memory_app_repository.dart';
import 'help_feedback_dialog.dart';
import 'reports_queue_sheet.dart';

class HelpFeedbackSettingsSection extends ConsumerWidget {
  const HelpFeedbackSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.settliv;
    final reports = ref.watch(allFeedbackReportsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HELP & FEEDBACK',
          style: AppTypography.caption.copyWith(
            color: theme.muted,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        GlassSurface(
          level: GlassLevel.level1,
          borderRadius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.bug_report_outlined, color: theme.ink),
                title: Text(
                  'Report a problem',
                  style: AppTypography.bodySemiBold.copyWith(
                    color: theme.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Let us know if calculations, views, or exports misbehave',
                  style: AppTypography.caption.copyWith(color: theme.muted, fontSize: 11.5),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: theme.muted),
                onTap: () => HelpFeedbackDialog.show(context, initialType: FeedbackType.problem),
              ),
              Divider(color: theme.hairline, height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.lightbulb_outline_rounded, color: theme.ink),
                title: Text(
                  'Request a feature',
                  style: AppTypography.bodySemiBold.copyWith(
                    color: theme.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Suggest ideas for new splits, payment rails, or charts',
                  style: AppTypography.caption.copyWith(color: theme.muted, fontSize: 11.5),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: theme.muted),
                onTap: () => HelpFeedbackDialog.show(context, initialType: FeedbackType.feature),
              ),
              Divider(color: theme.hairline, height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.history_edu_rounded, color: theme.ink),
                title: Row(
                  children: [
                    Text(
                      'Your reports',
                      style: AppTypography.bodySemiBold.copyWith(
                        color: theme.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (reports.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${reports.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: theme.accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  'View reports saved on this device or export them',
                  style: AppTypography.caption.copyWith(color: theme.muted, fontSize: 11.5),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: theme.muted),
                onTap: () => ReportsQueueSheet.show(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
