import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/adaptive_presenter.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../data/models/savings_goal.dart';
import '../../../../data/repositories/in_memory_app_repository.dart';

class SavingsGoalsSection extends ConsumerWidget {
  const SavingsGoalsSection({super.key});

  void _openCreateGoalDialog(BuildContext context, WidgetRef ref) {
    final theme = context.settliv;
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    final initialController = TextEditingController();
    DateTime? selectedDate;
    String? errorText;

    AdaptivePresenter.show(
      context: context,
      title: 'New savings goal',
      child: StatefulBuilder(
        builder: (dialogCtx, setDialogState) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GOAL NAME',
                style: AppTypography.caption.copyWith(
                  color: theme.muted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                autofocus: true,
                style: TextStyle(color: theme.ink),
                decoration: InputDecoration(
                  hintText: 'e.g. Goa Trip, New Phone, Emergency Fund',
                  hintStyle: TextStyle(color: theme.muted),
                  filled: true,
                  fillColor: theme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.hairline),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'TARGET AMOUNT (₹)',
                style: AppTypography.caption.copyWith(
                  color: theme.muted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: targetController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: theme.ink),
                decoration: InputDecoration(
                  hintText: 'e.g. 50,000',
                  hintStyle: TextStyle(color: theme.muted),
                  filled: true,
                  fillColor: theme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.hairline),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'INITIAL SAVINGS (OPTIONAL)',
                style: AppTypography.caption.copyWith(
                  color: theme.muted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: initialController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: theme.ink),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(color: theme.muted),
                  filled: true,
                  fillColor: theme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.hairline),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Target Date (Optional)',
                    style: TextStyle(color: theme.ink, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 90)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    icon: Icon(Icons.calendar_today_rounded, size: 16, color: theme.ink),
                    label: Text(
                      selectedDate != null
                          ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                          : 'Set date',
                      style: TextStyle(color: theme.ink),
                    ),
                  ),
                ],
              ),
              if (errorText != null) ...[
                const SizedBox(height: 12),
                Text(errorText!, style: TextStyle(color: theme.textCoral, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      setDialogState(() => errorText = 'Please enter a goal name');
                      return;
                    }
                    final targetRupees = double.tryParse(targetController.text.replaceAll(',', ''));
                    if (targetRupees == null || targetRupees <= 0) {
                      setDialogState(() => errorText = 'Please enter a valid target amount');
                      return;
                    }
                    final initialRupees = double.tryParse(initialController.text.replaceAll(',', '')) ?? 0.0;
                    final targetPaise = (targetRupees * 100).round();
                    final initialPaise = (initialRupees * 100).round();

                    final goal = SavingsGoal(
                      id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      targetPaise: targetPaise,
                      savedPaise: initialPaise,
                      targetDate: selectedDate,
                      createdAt: DateTime.now(),
                    );

                    ref.read(appStateProvider.notifier).addSavingsGoal(goal);
                    Navigator.of(dialogCtx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryButtonBg,
                    foregroundColor: theme.primaryButtonText,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Create Goal', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openContributionDialog(BuildContext context, WidgetRef ref, SavingsGoal goal, {required bool isDeposit}) {
    final theme = context.settliv;
    final controller = TextEditingController();
    String? errorText;

    AdaptivePresenter.show(
      context: context,
      title: isDeposit ? 'Add to ${goal.name}' : 'Withdraw from ${goal.name}',
      child: StatefulBuilder(
        builder: (dialogCtx, setDialogState) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Saved: ${CurrencyFormatter.formatPaise(goal.savedPaise)} of ${CurrencyFormatter.formatPaise(goal.targetPaise)}',
                style: TextStyle(color: theme.muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Text(
                'AMOUNT (₹)',
                style: AppTypography.caption.copyWith(
                  color: theme.muted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: TextStyle(color: theme.ink, fontSize: 18, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(color: theme.muted),
                  filled: true,
                  fillColor: theme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.hairline),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Quick amount chips
              Wrap(
                spacing: 8,
                children: [500, 1000, 2000, 5000].map((rupees) {
                  return ActionChip(
                    label: Text('+₹$rupees'),
                    onPressed: () {
                      final current = double.tryParse(controller.text) ?? 0;
                      controller.text = '${(current + rupees).toInt()}';
                      setDialogState(() {});
                    },
                  );
                }).toList(),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 12),
                Text(errorText!, style: TextStyle(color: theme.textCoral, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final amountRupees = double.tryParse(controller.text.replaceAll(',', ''));
                    if (amountRupees == null || amountRupees <= 0) {
                      setDialogState(() => errorText = 'Enter a valid amount');
                      return;
                    }
                    final amountPaise = (amountRupees * 100).round();
                    if (!isDeposit && amountPaise > goal.savedPaise) {
                      setDialogState(() => errorText = 'Cannot withdraw more than saved amount');
                      return;
                    }

                    if (isDeposit) {
                      ref.read(appStateProvider.notifier).contributeToSavingsGoal(goal.id, amountPaise);
                    } else {
                      ref.read(appStateProvider.notifier).withdrawFromSavingsGoal(goal.id, amountPaise);
                    }
                    Navigator.of(dialogCtx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryButtonBg,
                    foregroundColor: theme.primaryButtonText,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(isDeposit ? 'Add Contribution' : 'Confirm Withdrawal',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.settliv;
    final goals = ref.watch(allSavingsGoalsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SAVINGS GOALS',
              style: AppTypography.caption.copyWith(
                color: theme.muted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            TextButton.icon(
              onPressed: () => _openCreateGoalDialog(context, ref),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('New goal', style: TextStyle(fontSize: 12.5)),
              style: TextButton.styleFrom(
                foregroundColor: theme.ink,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (goals.isEmpty)
          GlassSurface(
            level: GlassLevel.level1,
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'No savings goals yet. Create one to track targets.',
                    style: AppTypography.caption.copyWith(color: theme.muted),
                  ),
                ),
                TextButton(
                  onPressed: () => _openCreateGoalDialog(context, ref),
                  child: Text('Create', style: TextStyle(color: theme.accent, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: goals.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final g = goals[index];
              final pct = (g.progress * 100).toInt();

              return GlassSurface(
                level: GlassLevel.level1,
                borderRadius: 18,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                g.name,
                                style: AppTypography.bodySemiBold.copyWith(
                                  color: theme.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (g.isAchieved) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.textEmerald.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Achieved',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: theme.textEmerald,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_horiz_rounded, color: theme.muted, size: 20),
                          padding: EdgeInsets.zero,
                          color: theme.surface,
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'withdraw', child: Text('Withdraw funds')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete goal', style: TextStyle(color: theme.textCoral)),
                            ),
                          ],
                          onSelected: (val) {
                            if (val == 'withdraw') {
                              _openContributionDialog(context, ref, g, isDeposit: false);
                            } else if (val == 'delete') {
                              ref.read(appStateProvider.notifier).deleteSavingsGoal(g.id);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${CurrencyFormatter.formatPaise(g.savedPaise)} saved',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: theme.ink,
                          ),
                        ),
                        Text(
                          'Target: ${CurrencyFormatter.formatPaise(g.targetPaise)} ($pct%)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: theme.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TweenAnimationBuilder<double>(
                      key: ValueKey('progress_${g.id}'),
                      tween: Tween<double>(begin: 0, end: g.progress),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 7,
                          backgroundColor: theme.hairline,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            g.isAchieved ? theme.textEmerald : theme.accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (g.targetDate != null)
                          Text(
                            'Target: ${g.targetDate!.day}/${g.targetDate!.month}/${g.targetDate!.year}',
                            style: TextStyle(fontSize: 11, color: theme.muted),
                          )
                        else
                          const SizedBox.shrink(),
                        OutlinedButton.icon(
                          onPressed: () => _openContributionDialog(context, ref, g, isDeposit: true),
                          icon: const Icon(Icons.add_rounded, size: 14),
                          label: const Text('Add funds', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.hairline),
                            foregroundColor: theme.ink,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
