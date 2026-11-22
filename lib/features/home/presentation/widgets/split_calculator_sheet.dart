import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/gradient_primary_button.dart';

class SplitCalculatorSheet extends StatefulWidget {
  const SplitCalculatorSheet({super.key});

  static Future<void> show(BuildContext context) {
    final theme = context.settliv;
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: theme.surfaceSolid,
      barrierColor: theme.scrim,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const SplitCalculatorSheet(),
    );
  }

  @override
  State<SplitCalculatorSheet> createState() => _SplitCalculatorSheetState();
}

class _SplitCalculatorSheetState extends State<SplitCalculatorSheet> {
  final TextEditingController _amountController = TextEditingController();
  int _peopleCount = 2;
  int _tipPercent = 0;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int get _baseAmountPaise {
    final text = _amountController.text.trim();
    final double? val = double.tryParse(text);
    if (val == null || val <= 0) return 0;
    return (val * 100).round();
  }

  int get _totalWithTipPaise {
    final base = _baseAmountPaise;
    if (base <= 0) return 0;
    final tipPaise = (base * _tipPercent) ~/ 100;
    return base + tipPaise;
  }

  int get _perPersonPaise {
    final total = _totalWithTipPaise;
    if (total <= 0 || _peopleCount <= 0) return 0;
    return total ~/ _peopleCount;
  }

  int get _remainderPaise {
    final total = _totalWithTipPaise;
    if (total <= 0 || _peopleCount <= 0) return 0;
    return total % _peopleCount;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final totalPaise = _totalWithTipPaise;
    final perPerson = _perPersonPaise;
    final remainder = _remainderPaise;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.muted.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Split Calculator',
                style: AppTypography.titleLarge.copyWith(color: theme.ink),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: theme.muted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Total bill amount input
          Text(
            'TOTAL BILL (₹)',
            style: AppTypography.eyebrow.copyWith(color: theme.muted),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            style: AppTypography.moneyMedium.copyWith(color: theme.ink),
            decoration: InputDecoration(
              hintText: '0.00',
              prefixText: '₹ ',
              prefixStyle: AppTypography.moneyMedium.copyWith(color: theme.muted),
              filled: true,
              fillColor: theme.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: theme.hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: theme.hairline),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Number of people
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PEOPLE',
                style: AppTypography.eyebrow.copyWith(color: theme.muted),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline_rounded, color: _peopleCount > 2 ? theme.ink : theme.muted),
                    onPressed: _peopleCount > 2 ? () => setState(() => _peopleCount--) : null,
                  ),
                  Text(
                    '$_peopleCount',
                    style: AppTypography.titleCard.copyWith(color: theme.ink),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline_rounded, color: theme.ink),
                    onPressed: () => setState(() => _peopleCount++),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tip percentage
          Text(
            'TIP / SERVICE CHARGE',
            style: AppTypography.eyebrow.copyWith(color: theme.muted),
          ),
          const SizedBox(height: 6),
          Row(
            children: [0, 5, 10, 15].map((tip) {
              final isSelected = _tipPercent == tip;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Semantics(
                    button: true,
                    selected: isSelected,
                    child: InkWell(
                      onTap: () => setState(() => _tipPercent = tip),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? theme.primaryButtonBg : theme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? theme.primaryButtonBg : theme.hairline,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$tip%',
                          style: AppTypography.caption.copyWith(
                            color: isSelected ? theme.primaryButtonText : theme.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Result Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.hairline),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Per person share',
                      style: AppTypography.body.copyWith(color: theme.muted),
                    ),
                    Text(
                      CurrencyFormatter.formatPaise(perPerson),
                      style: AppTypography.moneyMedium.copyWith(
                        color: theme.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (remainder > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Exact paise split',
                        style: AppTypography.caption.copyWith(color: theme.muted),
                      ),
                      Text(
                        '$remainder person gets +₹0.01',
                        style: AppTypography.caption.copyWith(color: theme.accent),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Divider(height: 1, color: theme.hairline),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total with tip',
                      style: AppTypography.caption.copyWith(color: theme.muted),
                    ),
                    Text(
                      CurrencyFormatter.formatPaise(totalPaise),
                      style: AppTypography.caption.copyWith(
                        color: theme.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Add as expense button
          GradientPrimaryButton(
            label: 'Add as expense',
            onPressed: totalPaise > 0
                ? () {
                    Navigator.pop(context);
                    context.push('/add', extra: {
                      'initialExpense': null,
                      'initialText': (_totalWithTipPaise / 100).toStringAsFixed(2),
                      'initialTabIndex': 1,
                    });
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
