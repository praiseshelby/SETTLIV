import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/glass_sheet_scaffold.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/text_action_button.dart';
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
    GlassSheetScaffold.show(
      context: context,
      title: 'Settle balance',
      isScrollControlled: true,
      child: SettleSheet(
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
  bool _isSubmitting = false;

  late AnimationController _celebrationController;

  int get _maxOwedPaise {
    final repo = ref.read(appRepositoryProvider);
    final summary = repo.getGroupSummary(widget.group.id);
    final currentUserId = repo.currentUserId;
    final debt = summary.debts.cast<SimplifiedDebt?>().firstWhere(
      (d) => d?.fromPersonId == currentUserId && d?.toPersonId == _payee?.id,
      orElse: () => null,
    );
    if (debt != null) return debt.amount;
    final net = summary.netBalances[currentUserId] ?? 0;
    return net < 0 ? -net : 0;
  }

  String? get _amountValidationError {
    final paise = _enteredAmountPaise;
    if (paise <= 0) return 'Amount cannot be ₹0';
    if (paise < 100) return 'Minimum settlement is ₹1';
    final max = _maxOwedPaise;
    if (max > 0 && paise > max) {
      return 'Cannot exceed ${CurrencyFormatter.formatPaise(max, absolute: true)} (what you owe)';
    }
    return null;
  }

  bool get _isAmountValid => _amountValidationError == null;

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
      final initialRupees = (debt.amount / 100).toStringAsFixed(
        debt.amount % 100 == 0 ? 0 : 2,
      );
      _amountController = TextEditingController(text: initialRupees);
      _step = SettleStep.amount;
    } else {
      // User owes nothing in this group!
      _payee = null;
      _amountController = TextEditingController(text: '0');
      _step = SettleStep.allSettled;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  int get _enteredAmountPaise {
    return CurrencyFormatter.parseToPaise(_amountController.text) ?? 0;
  }

  void _onPayViaUpi() {
    if (!_isAmountValid) return;
    setState(() => _step = SettleStep.upiPicker);
  }

  Future<void> _onSelectUpiApp(String appName) async {
    setState(() {
      _selectedUpiApp = appName;
      _step = SettleStep.simulation;
    });

    final upiId = _payee?.upiId ??
        '${(_payee?.name ?? "user").toLowerCase().replaceAll(' ', '')}@okaxis';
    final payeeName = _payee?.name ?? 'Settliv Member';
    final amountStr = (_enteredAmountPaise / 100).toStringAsFixed(2);
    final note = 'Settliv: ${widget.group.name}';

    final universalUri = Uri.parse(
      'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(payeeName)}&am=$amountStr&cu=INR&tn=${Uri.encodeComponent(note)}',
    );

    bool launched = false;
    try {
      if (await canLaunchUrl(universalUri)) {
        launched = await launchUrl(
          universalUri,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {
      launched = false;
    }

    if (!launched) {
      // Fallback for web or desktop without native UPI handler: copy UPI ID
      Clipboard.setData(ClipboardData(text: upiId));
      await Future.delayed(const Duration(milliseconds: 700));
    }

    if (mounted) {
      setState(() => _step = SettleStep.confirmation);
    }
  }

  void _onMarkPaidInCash() {
    if (!_isAmountValid) return;
    setState(() {
      _method = SettlementMethod.cash;
      _step = SettleStep.confirmation;
    });
  }

  Future<void> _onMarkPaid() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final repo = ref.read(appRepositoryProvider);
    final currentUserId = repo.currentUserId;
    final paise = _enteredAmountPaise;

    final settlement = Settlement(
      id: 'settle_${DateTime.now().millisecondsSinceEpoch}',
      groupId: widget.group.id,
      from: currentUserId,
      to: _payee?.id ?? '',
      paise: paise,
      method: _method,
      date: DateTime.now(),
    );

    // Record settlement in repository
    ref.read(appStateProvider.notifier).addSettlement(settlement);

    // Show celebration
    setState(() => _step = SettleStep.celebration);
    _celebrationController.forward(from: 0.0);

    await Future.delayed(const Duration(milliseconds: 1200));

    if (mounted) {
      Navigator.of(context).pop();
      UndoSnackbar.show(
        context: context,
        message:
            'Settled ${CurrencyFormatter.formatPaise(paise, absolute: true)} with ${_payee?.name ?? "payee"}',
        onUndo: () {
          ref.read(appStateProvider.notifier).deleteSettlement(settlement.id);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _buildStepContent(theme),
    );
  }

  Widget _buildStepContent(SettlivThemeExtension theme) {
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
  // Step 0: All Settled
  // ---------------------------------------------------------------------------
  Widget _buildAllSettledStep(SettlivThemeExtension theme) {
    return Column(
      key: const ValueKey('all_settled_step'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: theme.emeraldTint,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.done_all_rounded,
            color: theme.emerald,
            size: 28,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'All settled up in ${widget.group.name}',
          style: AppTypography.titleLarge.copyWith(
            color: theme.ink,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'You don\'t owe any money to members of this group.',
          style: AppTypography.body.copyWith(
            color: theme.muted,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Done',
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1: Amount + Payee confirmation + 2 Method buttons
  // ---------------------------------------------------------------------------
  Widget _buildAmountStep(SettlivThemeExtension theme) {
    final maxOwed = _maxOwedPaise;
    final maxFormatted = CurrencyFormatter.formatPaise(maxOwed, absolute: true);

    return Column(
      key: const ValueKey('amount_step'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Payee Card
        if (_payee != null) ...[
          GlassSurface(
            level: GlassLevel.level1,
            borderRadius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                PersonAvatar(person: _payee, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paying ${_payee!.name}',
                        style: AppTypography.bodyMedium.copyWith(
                          color: theme.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'You owe $maxFormatted in ${widget.group.name}',
                        style: AppTypography.caption.copyWith(
                          color: theme.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Amount Input Field
        Text(
          'SETTLEMENT AMOUNT (₹)',
          style: AppTypography.caption.copyWith(
            color: theme.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppTypography.heroMoney.copyWith(
            color: theme.ink,
            fontSize: 32,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            prefixText: '₹ ',
            prefixStyle: AppTypography.heroMoney.copyWith(
              color: theme.muted,
              fontSize: 32,
            ),
            filled: true,
            fillColor: theme.raised,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: theme.hairline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: theme.hairline),
            ),
            errorText: _amountValidationError,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),

        // Quick "Settle full amount" chip if partial
        if (maxOwed > 0 && _enteredAmountPaise != maxOwed) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () {
                final rupees = (maxOwed / 100).toStringAsFixed(
                  maxOwed % 100 == 0 ? 0 : 2,
                );
                setState(() => _amountController.text = rupees);
              },
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.emeraldTint,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: theme.emerald.withValues(alpha: 0.28),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Set full balance ($maxFormatted)',
                  style: AppTypography.caption.copyWith(
                    color: theme.textEmerald,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          const SizedBox(height: 8),
        ],

        // 2 Primary Choice Cards: "Pay with UPI" & "Mark as Cash"
        Row(
          children: [
            Expanded(
              child: _buildMethodCard(
                title: 'Pay with UPI',
                subtitle: 'GPay, PhonePe, Paytm',
                icon: Icons.qr_code_rounded,
                isPrimary: true,
                onTap: _isAmountValid ? _onPayViaUpi : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMethodCard(
                title: 'Paid in Cash',
                subtitle: 'Record without UPI',
                icon: Icons.payments_rounded,
                isPrimary: false,
                onTap: _isAmountValid ? _onMarkPaidInCash : null,
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

    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isPrimary ? theme.navy : theme.raised,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isPrimary ? theme.navy : theme.hairline,
            ),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: theme.shadow.withValues(alpha: theme.isDark ? 0.3 : 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isPrimary ? theme.onNavy : theme.ink,
                size: 24,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: AppTypography.body.copyWith(
                  color: isPrimary ? theme.onNavy : theme.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.caption.copyWith(
                  color: isPrimary
                      ? theme.onNavy.withValues(alpha: 0.75)
                      : theme.muted,
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
    final upiId = _payee?.upiId ??
        '${(_payee?.name ?? "user").toLowerCase().replaceAll(' ', '')}@okaxis';

    final upiApps = [
      ('GPay', theme.navy, Icons.account_balance_wallet_rounded),
      ('PhonePe', theme.orchid, Icons.phone_android_rounded),
      ('Paytm', theme.teal, Icons.wallet_rounded),
      ('BHIM', theme.saffron, Icons.assured_workload_rounded),
      ('Other UPI', theme.muted, Icons.apps_rounded),
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
              style: AppTypography.sectionHeader.copyWith(
                color: theme.ink,
                fontSize: 15,
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _step = SettleStep.amount),
              child: Text(
                'Change amount',
                style: AppTypography.caption.copyWith(
                  color: theme.isDark ? theme.ink : theme.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        for (final app in upiApps) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => _onSelectUpiApp(app.$1),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: theme.raised,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.hairline),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: app.$2.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(app.$3, color: app.$2, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        app.$1,
                        style: AppTypography.bodyMedium.copyWith(
                          color: theme.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: theme.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 8),
        // Fallback: Copy UPI ID
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.raised,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Direct Payment',
                style: AppTypography.caption.copyWith(
                  color: theme.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'UPI ID: $upiId',
                    style: AppTypography.caption.copyWith(
                      color: theme.muted,
                      fontSize: 12,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: upiId));
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
                          color: _copiedUpi ? theme.textEmerald : theme.ink,
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
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.raised,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: theme.hairline,
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 14,
                  color: theme.textEmerald,
                ),
                const SizedBox(width: 6),
                Text(
                  'Live UPI intent & auto-fallback',
                  style: AppTypography.caption.copyWith(
                    color: theme.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
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
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(theme.navy),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Opening $_selectedUpiApp…',
              style: AppTypography.titleLarge.copyWith(
                color: theme.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Simulating payment hand-off',
              style: AppTypography.body.copyWith(color: theme.muted),
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
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          _method == SettlementMethod.cash
              ? 'Marked as paid in cash'
              : 'Paid via $_selectedUpiApp',
          style: AppTypography.caption.copyWith(color: theme.muted),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Mark paid',
          leading: Icon(Icons.check_rounded, color: theme.primaryButtonText, size: 20),
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
    final confettiColors = [
      theme.emerald,
      theme.navy,
      theme.saffron,
      theme.orchid,
      theme.teal,
      theme.coral,
    ];

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
                painter: _ConfettiPainter(
                  progress: _celebrationController.value,
                  colors: confettiColors,
                ),
              ),
              Transform.scale(
                scale: 0.8 + (0.25 * _celebrationController.value),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: theme.emerald,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.emerald.withValues(alpha: 0.35),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.check_rounded,
                      color: theme.white,
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
  final List<Color> colors;

  const _ConfettiPainter({
    required this.progress,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || colors.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
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

      canvas.drawCircle(Offset(x, y), 3.2 * (1.0 - (progress * 0.5)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress || !listEquals(oldDelegate.colors, colors);
}
