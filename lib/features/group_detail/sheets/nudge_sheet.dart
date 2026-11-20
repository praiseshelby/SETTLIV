import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/glass_sheet_scaffold.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/engine/balance_engine.dart';
import '../../../data/models/group.dart';
import '../../../data/models/person.dart';

class NudgeSheet extends StatelessWidget {
  final Group group;
  final SimplifiedDebt? debt;
  final Person? debtor;
  final int? amountPaise;

  const NudgeSheet({
    super.key,
    required this.group,
    this.debt,
    this.debtor,
    this.amountPaise,
  });

  static Future<void> show({
    required BuildContext context,
    required Group group,
    SimplifiedDebt? debt,
    Person? debtor,
    int? amountPaise,
  }) {
    final theme = context.settliv;
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: theme.transparent,
      barrierColor: theme.scrim,
      builder: (_) => NudgeSheet(
        group: group,
        debt: debt,
        debtor: debtor,
        amountPaise: amountPaise,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final targetName = debtor?.name ?? 'roommate';
    final formattedAmount = amountPaise != null
        ? CurrencyFormatter.formatPaise(amountPaise!, absolute: true)
        : null;

    final String messageText = formattedAmount != null
        ? 'Hey $targetName, friendly nudge to settle $formattedAmount for ${group.name} on Settliv when you get a chance!'
        : 'Hey everyone, friendly nudge to check the latest balances for ${group.name} on Settliv!';

    return GlassSheetScaffold(
      title: 'Send a nudge',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (debtor != null) ...[
            Row(
              children: [
                PersonAvatar(person: debtor, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        targetName,
                        style: AppTypography.titleMedium.copyWith(
                          color: theme.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (formattedAmount != null)
                        Text(
                          'Owes $formattedAmount in ${group.name}',
                          style: AppTypography.caption.copyWith(
                            color: theme.textCoral,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
          ],
          Text(
            'Message preview',
            style: AppTypography.sectionHeader.copyWith(
              color: theme.muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.raised,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.hairline),
            ),
            child: Text(
              messageText,
              style: AppTypography.body.copyWith(
                color: theme.ink,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Copy reminder message',
            leading: Icon(Icons.copy_rounded, color: theme.primaryButtonText, size: 18),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: messageText));
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Reminder message copied to clipboard!',
                      style: TextStyle(fontFamily: 'Manrope'),
                    ),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 3),
                    backgroundColor: theme.navy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
