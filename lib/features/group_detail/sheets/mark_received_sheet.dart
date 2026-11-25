import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/adaptive_presenter.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/undo_snackbar.dart';
import '../../../data/engine/person_balance_engine.dart';
import '../../../data/models/group.dart';
import '../../../data/models/person.dart';
import '../../../data/models/settlement.dart';
import '../../../data/repositories/in_memory_app_repository.dart';

class MarkReceivedSheet extends ConsumerStatefulWidget {
  final Person payer;
  final Group? group;
  final int maxAmountPaise;
  final PersonDebtSummary? summary;
  final void Function(List<Settlement> created)? onRecorded;
  final void Function(List<String> undoneIds)? onUndone;

  const MarkReceivedSheet({
    super.key,
    required this.payer,
    this.group,
    required this.maxAmountPaise,
    this.summary,
    this.onRecorded,
    this.onUndone,
  });

  static Future<void> show({
    required BuildContext context,
    required Person payer,
    Group? group,
    required int maxAmountPaise,
    PersonDebtSummary? summary,
    void Function(List<Settlement> created)? onRecorded,
    void Function(List<String> undoneIds)? onUndone,
  }) {
    return AdaptivePresenter.show<void>(
      context: context,
      title: 'Received from ${payer.name}',
      maxWidth: 440,
      child: MarkReceivedSheet(
        payer: payer,
        group: group,
        maxAmountPaise: maxAmountPaise,
        summary: summary,
        onRecorded: onRecorded,
        onUndone: onUndone,
      ),
    );
  }

  @override
  ConsumerState<MarkReceivedSheet> createState() => _MarkReceivedSheetState();
}

class _MarkReceivedSheetState extends ConsumerState<MarkReceivedSheet>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _amountController;
  final TextEditingController _noteController = TextEditingController();
  SettlementMethod _method = SettlementMethod.upi;
  bool _hasAttempted = false;
  bool _isSubmitting = false;
  bool _showSuccess = false;
  late final AnimationController _checkController;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    final initialRupees = (widget.maxAmountPaise / 100).toStringAsFixed(
      widget.maxAmountPaise % 100 == 0 ? 0 : 2,
    );
    _amountController = TextEditingController(text: initialRupees);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  int get _enteredAmountPaise =>
      CurrencyFormatter.parseToPaise(_amountController.text) ?? 0;

  String? get _validationError {
    final paise = _enteredAmountPaise;
    if (paise <= 0) return 'Enter an amount greater than ₹0';
    if (paise < 100) return 'Minimum amount is ₹1';
    if (widget.maxAmountPaise > 0 && paise > widget.maxAmountPaise) {
      return 'Cannot exceed ${CurrencyFormatter.formatPaise(widget.maxAmountPaise, absolute: true)} (what ${widget.payer.name} owes)';
    }
    return null;
  }

  Future<void> _onSubmit() async {
    if (_isSubmitting) return;
    setState(() => _hasAttempted = true);
    if (_validationError != null) return;

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    final repo = ref.read(appRepositoryProvider);
    final notifier = ref.read(appStateProvider.notifier);
    final currentUserId = repo.currentUserId;
    final paise = _enteredAmountPaise;
    final now = DateTime.now();
    final trimmedNote = _noteController.text.trim();
    final note = trimmedNote.isEmpty ? null : trimmedNote;

    final List<Settlement> created = [];
    final baseTs = now.millisecondsSinceEpoch;

    if (widget.summary != null && widget.summary!.lines.length > 1) {
      final lines = widget.summary!.lines.where((l) => l.paise != 0).toList();
      final allPositive = lines.every((l) => l.personOwesUser);
      if (allPositive || paise < widget.maxAmountPaise) {
        int remaining = paise;
        for (final line in lines.where((l) => l.personOwesUser)) {
          if (remaining <= 0) break;
          final take = math.min(remaining, line.amountPaise);
          if (take <= 0) continue;
          final s = Settlement(
            id: 'rcv_${line.groupId}_${baseTs}_${created.length}',
            groupId: line.groupId,
            from: widget.payer.id,
            to: currentUserId,
            paise: take,
            method: _method,
            date: now,
            note: note,
          );
          notifier.addSettlement(s);
          created.add(s);
          remaining -= take;
        }
      } else {
        // Mixed-direction full receipt: settle each group line so every group's
        // ledger balances cleanly to zero without negative balances.
        for (final line in lines) {
          final fromId = line.personOwesUser ? widget.payer.id : currentUserId;
          final toId = line.personOwesUser ? currentUserId : widget.payer.id;
          final s = Settlement(
            id: 'rcv_net_${line.groupId}_${baseTs}_${created.length}',
            groupId: line.groupId,
            from: fromId,
            to: toId,
            paise: line.amountPaise,
            method: _method,
            date: now,
            note: note,
          );
          notifier.addSettlement(s);
          created.add(s);
        }
      }
    } else {
      final groupId = widget.group?.id ??
          widget.summary?.lines.firstOrNull?.groupId ??
          repo.getGroups().firstWhere((g) => !g.isPersonal).id;
      final s = Settlement(
        id: 'rcv_${groupId}_$baseTs',
        groupId: groupId,
        from: widget.payer.id,
        to: currentUserId,
        paise: paise,
        method: _method,
        date: now,
        note: note,
      );
      notifier.addSettlement(s);
      created.add(s);
    }

    widget.onRecorded?.call(created);

    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    setState(() => _showSuccess = true);
    if (disableAnimations) {
      _checkController.value = 1.0;
    } else {
      await _checkController.forward(from: 0.0);
      await Future.delayed(const Duration(milliseconds: 140));
    }

    if (mounted) {
      final createdIds = created.map((s) => s.id).toList();
      final msg =
          'Marked ${CurrencyFormatter.formatPaise(paise, absolute: true)} received from ${widget.payer.name}';
      Navigator.of(context).pop();
      UndoSnackbar.show(
        context: context,
        message: msg,
        onUndo: () {
          for (final id in createdIds) {
            notifier.deleteSettlement(id);
          }
          widget.onUndone?.call(createdIds);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    if (_showSuccess) {
      final curved = CurvedAnimation(
        parent: _checkController,
        curve: Curves.easeOutCubic,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.65, end: 1.0).animate(curved),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.emerald.withValues(alpha: 0.14),
                    border: Border.all(color: theme.emerald, width: 2),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: theme.textEmerald,
                    size: 32,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Payment recorded',
              style: AppTypography.titleMedium.copyWith(
                color: theme.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${CurrencyFormatter.formatPaise(_enteredAmountPaise, absolute: true)} · ${_method.label}',
              style: AppTypography.caption.copyWith(
                color: theme.textEmerald,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    final displayPaise =
        _enteredAmountPaise > 0 ? _enteredAmountPaise : widget.maxAmountPaise;
    final error = _hasAttempted ? _validationError : null;
    final groupSubtitle = widget.group != null
        ? 'In ${widget.group!.name}'
        : (widget.summary != null && widget.summary!.lines.length > 1
            ? 'Across ${widget.summary!.lines.length} groups'
            : (widget.summary?.lines.firstOrNull != null
                ? 'In ${widget.summary!.lines.first.groupName}'
                : 'Group balance'));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Payer header row
        Row(
          children: [
            PersonAvatar(person: widget.payer, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    groupSubtitle,
                    style: AppTypography.caption.copyWith(
                      color: theme.muted,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Owes you up to ${CurrencyFormatter.formatPaise(widget.maxAmountPaise, absolute: true)}',
                    style: AppTypography.caption.copyWith(
                      color: theme.textEmerald,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Amount field
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(
            fontFamily: AppTypography.fontDisplay,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: theme.ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            prefixText: '₹ ',
            prefixStyle: TextStyle(
              fontFamily: AppTypography.fontDisplay,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: theme.ink,
            ),
            labelText: 'Amount received',
            errorText: error,
            filled: true,
            fillColor: theme.raised,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.hairline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.hairline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.emerald, width: 1.5),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),

        // Method chips: UPI, Cash, Other
        Row(
          children: SettlementMethod.values.map((m) {
            final selected = _method == m;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: m == SettlementMethod.other ? 0 : 8,
                ),
                child: Material(
                  color: selected
                      ? theme.emerald.withValues(alpha: 0.14)
                      : theme.raised,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _method = m),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? theme.emerald : theme.hairline,
                          width: selected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (selected) ...[
                            Icon(
                              Icons.check_rounded,
                              size: 15,
                              color: theme.textEmerald,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              m.label,
                              style: AppTypography.caption.copyWith(
                                color:
                                    selected ? theme.textEmerald : theme.ink,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        // Optional note
        TextField(
          controller: _noteController,
          maxLength: 140,
          style: AppTypography.body.copyWith(color: theme.ink, fontSize: 13.5),
          decoration: InputDecoration(
            hintText: 'Add a note (optional)',
            hintStyle: AppTypography.caption.copyWith(color: theme.muted),
            counterText: '',
            filled: true,
            fillColor: theme.raised,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.hairline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.hairline),
            ),
          ),
        ),
        const SizedBox(height: 10),

        Text(
          'This only records it. Settliv does not move money.',
          style: AppTypography.caption.copyWith(
            color: theme.muted,
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 14),

        // Primary button (always tappable)
        SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.emerald,
              foregroundColor: theme.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            onPressed: _onSubmit,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Mark ${CurrencyFormatter.formatPaise(displayPaise, absolute: true)} received',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
