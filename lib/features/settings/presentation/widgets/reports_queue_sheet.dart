import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/adaptive_presenter.dart';
import '../../../../data/models/feedback_report.dart';
import '../../../../data/repositories/in_memory_app_repository.dart';

class ReportsQueueSheet extends ConsumerWidget {
  const ReportsQueueSheet({super.key});

  static Future<void> show(BuildContext context) {
    return AdaptivePresenter.show(
      context: context,
      title: 'Your reports',
      child: const ReportsQueueSheet(),
    );
  }

  Future<void> _sendByEmail(FeedbackReport report) async {
    final subject = Uri.encodeComponent('[Settliv Feedback] ${report.type.label}: ${report.category}');
    final body = Uri.encodeComponent(report.formatAsText());
    final uri = Uri.parse('mailto:${AppConfig.kFeedbackEmail}?subject=$subject&body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.settliv;
    final reports = ref.watch(allFeedbackReportsProvider);

    if (reports.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: theme.muted),
              const SizedBox(height: 12),
              Text(
                'No reports submitted yet',
                style: AppTypography.titleMedium.copyWith(color: theme.ink),
              ),
              const SizedBox(height: 4),
              Text(
                'Feedback and issue reports you submit are saved locally here.',
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(color: theme.muted),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final r = reports[index];
        final dateStr = '${r.createdAt.day}/${r.createdAt.month}/${r.createdAt.year}';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: r.type == FeedbackType.problem
                          ? theme.textCoral.withValues(alpha: 0.1)
                          : theme.textEmerald.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      r.type.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: r.type == FeedbackType.problem ? theme.textCoral : theme.textEmerald,
                      ),
                    ),
                  ),
                  Text(
                    dateStr,
                    style: TextStyle(fontSize: 12, color: theme.muted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                r.category,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.ink),
              ),
              const SizedBox(height: 4),
              Text(
                r.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: theme.muted),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_clock_outlined, size: 14, color: theme.muted),
                      const SizedBox(width: 4),
                      Text(
                        r.status,
                        style: TextStyle(fontSize: 11.5, color: theme.muted, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Copy report',
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        color: theme.ink,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: r.formatAsText()));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Report copied to clipboard!')),
                          );
                        },
                      ),
                      if (AppConfig.kFeedbackEmail.isNotEmpty)
                        IconButton(
                          tooltip: 'Send by email',
                          icon: const Icon(Icons.email_outlined, size: 16),
                          color: theme.ink,
                          onPressed: () => _sendByEmail(r),
                        ),
                      IconButton(
                        tooltip: 'Delete report',
                        icon: Icon(Icons.delete_outline_rounded, size: 16, color: theme.textCoral),
                        onPressed: () {
                          ref.read(appStateProvider.notifier).deleteFeedbackReport(r.id);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
