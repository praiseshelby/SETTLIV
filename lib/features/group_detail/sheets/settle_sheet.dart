import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/coming_soon_tag.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/text_action_button.dart';
import '../../../core/widgets/sheet_scaffold.dart';
import '../../../core/widgets/undo_snackbar.dart';
import '../../../data/engine/balance_engine.dart';
import '../../../data/models/group.dart';
import '../../../data/models/person.dart';
import '../../../data/models/settlement.dart';
import '../../../data/repositories/in_memory_app_repository.dart';

enum SettleStep {
  amount,
  upiPicker,
  simulation,
  confirmation,
  celebration,
  allSettled,
}

class SettleSheet extends ConsumerStatefulWidget {
  final Group group;
  final SimplifiedDebt? preselectedDebt;

  const SettleSheet({
    super.key,
    required this.group,
    this.preselectedDebt,
  });

  static void show({
    required BuildContext context,
    required Group group,
    SimplifiedDebt? preselectedDebt,
  }) {
    SheetScaffold.show(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SettleSheet(
        group: group,
        preselectedDebt: preselectedDebt,
      ),
    );
  }

  @override
  ConsumerState<SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends ConsumerState<SettleSheet>
    with SingleTickerProviderStateMixin {
  late SettleStep _step;
  late final TextEditingController _amountController;
  late Person? _payee;
  SettlementMethod _method = SettlementMethod.upi;
  String _selectedUpiApp = 'GPay';
  bool _copiedUpi = false;

  late AnimationController _celebrationController;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    final repo = ref.read(appRepositoryProvider);
    final summary = repo.getGroupSummary(widget.group.id);
    final currentUserId = repo.currentUserId;

    // Find candidate debt where user owes someone
    SimplifiedDebt? debt = widget.preselectedDebt;
    if (debt == null) {
      final userDebts =
          summary.debts.where((d) => d.fromPersonId == currentUserId).toList();
      if (userDebts.isNotEmpty) {
        debt = userDebts.first;
      }
    }

    if (debt != null) {
      _payee = repo.getPerson(debt.toPersonId);
      final r = debt.amount ~/ 100;
      final f = debt.amount % 100;
      final str = f > 0 ? '$r.${f.toString().padLeft(2, '0')}' : r.toString();
      _amountController = TextEditingController(text: str);
      _step = SettleStep.amount;
    } else {
      final userNet = summary.netBalances[currentUserId] ?? 0;
      if (userNet >= 0) {
        _payee = null;
        _amountController = TextEditingController(text: '0');
        _step = SettleStep.allSettled;
      } else {
        // Fallback: pick any other member
        final otherMembers = widget.group.memberIds
            .where((id) => id != currentUserId)
            .toList();
        _payee = otherMembers.isNotEmpty
            ? repo.getPerson(otherMembers.first)
            : null;
        _amountController = TextEditingController(text: '100');
        _step = SettleStep.amount;
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  int get _enteredAmountPaise =>
      CurrencyFormatter.parseToPaise(_amountController.text) ?? 0;

  void _onChooseMethod(SettlementMethod method) {
    setState(() => _method = method);
    if (method == SettlementMethod.cash) {
      // Mark as cash skips UPI picker directly to confirmation
      setState(() => _step = SettleStep.confirmation);
    } else {
      setState(() => _step = SettleStep.upiPicker);
    }
  }

  void _onSelectUpiApp(String appName) {
    setState(() {
      _selectedUpiApp = appName;
      _step = SettleStep.simulation;
    });

    // ~900ms simulation with progress ring
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() => _step = SettleStep.confirmation);
      }
    });
  }

  Future<void> _onMarkPaid() async {
    setState(() => _step = SettleStep.celebration);
    _celebrationController.forward(from: 0);

    final repoNotifier = ref.read(appStateProvider.notifier);
    final settlement = Settlement(
      id: 'stl_${DateTime.now().millisecondsSinceEpoch}',
      groupId: widget.group.id,
      payerId: ref.read(appRepositoryProvider).currentUserId,
      payeeId: _payee?.id ?? '',
      amount: _enteredAmountPaise,
      date: DateTime.now(),
      method: _method,
      note: 'Settliv · ${widget.group.name}',
    );

    // Apply settlement in state
    repoNotifier.addSettlement(settlement);

    // Celebration duration (<1.2s)
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;

    Navigator.of(context).pop();

    UndoSnackbar.show(
      context: context,
      message:
          'Settled ${CurrencyFormatter.formatPaise(settlement.amount, absolute: true)} with ${_payee?.name ?? "payee"}',
      onUndo: () {
        repoNotifier.deleteSettlement(settlement.id);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        child: _buildCurrentStep(theme),
      ),
    );
  }

  Widget _buildCurrentStep(SettlivThemeExtension theme) {
    switch (_step) {
      case SettleStep.allSettled:
        return _buildAllSettledStep(theme);
      case SettleStep.amount:
        return _buildAmountStep(theme);
      case SettleStep.upiPicker:
        return _buildUpiPickerStep(theme);
      case SettleStep.simulation:
        return _buildSimulationStep(theme);
      case SettleStep.confirmation:
        return _buildConfirmationStep(theme);
      case SettleStep.celebration:
        return _buildCelebrationStep(theme);
    }
  }

  // ---------------------------------------------------------------------------
  // Step: All Settled
  // ---------------------------------------------------------------------------
  Widget _buildAllSettledStep(SettlivThemeExtension theme) {
    return Column(
      key: const ValueKey('all_settled'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.emeraldTint,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(
              Icons.check_circle_rounded,
              color: AppColors.emerald,
              size: 38,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'All settled up!',
          style: AppTypography.titleLarge.copyWith(color: theme.ink),
        ),
        const SizedBox(height: 6),
        Text(
          'You don’t owe anyone in ${widget.group.name}. Everything is even.',
          style: AppTypography.body.copyWith(color: theme.secondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Done',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1: Amount & Payee Selection
  // ---------------------------------------------------------------------------
  Widget _buildAmountStep(SettlivThemeExtension theme) {
    return Column(
      key: const ValueKey('amount_step'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            PersonAvatar(person: _payee, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settling with ${_payee?.name ?? 'payee'}',
                    style: AppTypography.bodyMedium.copyWith(color: theme.ink),
                  ),
                  Text(
                    '${widget.group.name} plan',
                    style: AppTypography.caption.copyWith(color: theme.secondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Center(
          child: SizedBox(
            width: 240,
            child: TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: AppTypography.displayMoney.copyWith(
                color: theme.ink,
                fontSize: 40,
              ),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: AppTypography.displayMoney.copyWith(
                  color: theme.secondary,
                  fontSize: 32,
                ),
                hintText: '0',
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Choose payment method',
          style: AppTypography.caption.copyWith(
            color: theme.secondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMethodCard(
                title: 'Pay via UPI',
                subtitle: 'Simulated GPay, PhonePe, BHIM',
                icon: Icons.qr_code_rounded,
                isPrimary: true,
                onTap: _enteredAmountPaise > 0
                    ? () => _onChooseMethod(SettlementMethod.upi)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMethodCard(
                title: 'Mark as cash',
                subtitle: 'Handed over in person',
                icon: Icons.payments_rounded,
                isPrimary: false,
                onTap: _enteredAmountPaise > 0
                    ? () => _onChooseMethod(SettlementMethod.cash)
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMethodCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback? onTap,
  }) {
    final theme = context.settliv;
    final isDark = context.isDarkMode;

    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isPrimary
                ? (isDark ? const Color(0xFF233664) : AppColors.midnightNavy)
                : theme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPrimary ? Colors.transparent : theme.hairline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isPrimary ? Colors.white : AppColors.teal,
                size: 24,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: AppTypography.bodyMedium.copyWith(
                  color: isPrimary ? Colors.white : theme.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.caption.copyWith(
                  color: isPrimary
                      ? Colors.white.withValues(alpha: 0.75)
                      : theme.secondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2: UPI App Picker
  // ---------------------------------------------------------------------------
  Widget _buildUpiPickerStep(SettlivThemeExtension theme) {
    final mockUpiId = '${_payee?.name.toLowerCase() ?? "user"}@okaxis';

    final upiApps = [
      ('GPay', const Color(0xFF1A73E8), Icons.account_balance_wallet_rounded),
      ('PhonePe', const Color(0xFF5F259F), Icons.phone_android_rounded),
      ('Paytm', const Color(0xFF002970), Icons.wallet_rounded),
      ('BHIM', const Color(0xFFE26126), Icons.assured_workload_rounded),
      ('Other UPI', theme.secondary, Icons.apps_rounded),
    ];

    return Column(
      key: const ValueKey('upi_picker_step'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Select UPI App',
              style: AppTypography.sectionHeader.copyWith(color: theme.ink),
            ),
            GestureDetector(
              onTap: () => setState(() => _step = SettleStep.amount),
              child: Text(
                'Change amount',
                style: AppTypography.caption.copyWith(
                  color: AppColors.cobaltGlow,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Grid of monogram tiles
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final app in upiApps) ...[
              Semantics(
                button: true,
                label: 'Pay via ${app.$1}',
                child: InkWell(
                  onTap: () => _onSelectUpiApp(app.$1),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: app.$2.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: app.$2.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        app.$1.substring(0, math.min(2, app.$1.length)),
                        style: AppTypography.bodyMedium.copyWith(
                          color: app.$2,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
        // Note preview card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.raised,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'UPI Note preview:',
                style: AppTypography.caption.copyWith(color: theme.secondary),
              ),
              const SizedBox(height: 2),
              Text(
                'Settliv · ${widget.group.name} · Split balance',
                style: AppTypography.bodyMedium.copyWith(
                  color: theme.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'UPI ID: $mockUpiId',
                    style: AppTypography.caption.copyWith(
                      color: theme.secondary,
                      fontSize: 12,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: mockUpiId));
                      setState(() => _copiedUpi = true);
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) setState(() => _copiedUpi = false);
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        _copiedUpi ? 'Copied!' : 'Copy UPI ID',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.cobaltGlow,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: ComingSoonTag(
            label: 'Real UPI app launch comes in the full app',
            featureDescription:
                'On iOS and Android, tapping launches GPay/PhonePe directly using UPI deep links.',
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3: Simulation Ring (~900ms)
  // ---------------------------------------------------------------------------
  Widget _buildSimulationStep(SettlivThemeExtension theme) {
    return Padding(
      key: const ValueKey('simulation_step'),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 54,
              height: 54,
              child: CircularProgressIndicator(
                strokeWidth: 3.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.emerald),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Opening $_selectedUpiApp…',
              style: AppTypography.titleLarge.copyWith(color: theme.ink),
            ),
            const SizedBox(height: 6),
            Text(
              'Simulating payment hand-off',
              style: AppTypography.body.copyWith(color: theme.secondary),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 4: Confirmation Step
  // ---------------------------------------------------------------------------
  Widget _buildConfirmationStep(SettlivThemeExtension theme) {
    final amountFormatted =
        CurrencyFormatter.formatPaise(_enteredAmountPaise, absolute: true);

    return Column(
      key: const ValueKey('confirmation_step'),
      mainAxisSize: MainAxisSize.min,
      children: [
        PersonAvatar(person: _payee, size: 56),
        const SizedBox(height: 14),
        Text(
          'Did you pay $amountFormatted to ${_payee?.name ?? "payee"}?',
          style: AppTypography.titleLarge.copyWith(
            color: theme.ink,
            fontSize: 20,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          _method == SettlementMethod.cash
              ? 'Marked as paid in cash'
              : 'Paid via $_selectedUpiApp',
          style: AppTypography.caption.copyWith(color: theme.secondary),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Mark paid',
          variant: PrimaryButtonVariant.emeraldConfirm,
          leading: const Icon(Icons.check_rounded, color: Colors.white),
          onPressed: _onMarkPaid,
        ),
        const SizedBox(height: 10),
        TextActionButton(
          label: 'Not yet',
          variant: TextActionButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 5: Refined Celebration Moment (<1.2s)
  // ---------------------------------------------------------------------------
  Widget _buildCelebrationStep(SettlivThemeExtension theme) {
    return AnimatedBuilder(
      key: const ValueKey('celebration_step'),
      animation: _celebrationController,
      builder: (context, child) {
        return SizedBox(
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(200, 180),
                painter: _ConfettiPainter(progress: _celebrationController.value),
              ),
              Transform.scale(
                scale: 0.8 + (0.3 * _celebrationController.value),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.emerald,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emerald.withValues(alpha: 0.4),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;

  const _ConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final colors = [
      AppColors.emerald,
      AppColors.saffron,
      AppColors.teal,
      AppColors.orchid,
      AppColors.coral,
    ];

    const count = 16;
    for (int i = 0; i < count; i++) {
      final angle = (i * (2 * math.pi / count));
      final distance = 30 + (progress * 65);
      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;
      final paint = Paint()
        ..color = colors[i % colors.length]
            .withValues(alpha: (1.0 - progress).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), 3.5 * (1.0 - (progress * 0.5)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
