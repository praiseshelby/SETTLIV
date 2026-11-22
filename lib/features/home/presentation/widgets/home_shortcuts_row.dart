import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../add_expense/presentation/widgets/scan_sheet.dart';
import '../../domain/shortcut_engine.dart';
import 'split_calculator_sheet.dart';

class HomeShortcutsRow extends StatefulWidget {
  const HomeShortcutsRow({super.key});

  @override
  State<HomeShortcutsRow> createState() => _HomeShortcutsRowState();
}

class _HomeShortcutsRowState extends State<HomeShortcutsRow> {
  static const String _kShortcutPrefsKey = 'settliv_shortcut_usages_v1';
  List<ShortcutDefinition> _shortcuts = [];
  Map<ShortcutId, ShortcutUsage> _usages = {};

  @override
  void initState() {
    super.initState();
    _loadShortcutsOnAppOpen();
  }

  Future<void> _loadShortcutsOnAppOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kShortcutPrefsKey);
    final now = DateTime.now();

    if (jsonStr != null && jsonStr.isNotEmpty) {
      _usages = ShortcutEngine.deserializeUsages(jsonStr);
      _usages = ShortcutEngine.decayAll(_usages, now);
    } else {
      _usages = ShortcutEngine.decayAll({}, now);
    }

    _shortcuts = ShortcutEngine.rankShortcuts(_usages);
    if (mounted) setState(() {});
  }

  Future<void> _onShortcutTapped(ShortcutDefinition shortcut) async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    _usages = ShortcutEngine.recordTap(_usages, shortcut.id, now);

    // Persist counters
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kShortcutPrefsKey, ShortcutEngine.serializeUsages(_usages));

    // Note: Do NOT re-rank while the user is looking at the screen, as per spec:
    // "Order is recomputed on app open, never while the user is looking at it."

    if (!mounted) return;

    switch (shortcut.id) {
      case ShortcutId.scanReceipt:
        ScanSheet.show(context);
        break;

      case ShortcutId.pasteSms:
        context.push('/add', extra: {'initialTabIndex': 0});
        break;

      case ShortcutId.budgets:
        context.push('/insights/budgets');
        break;

      case ShortcutId.recurring:
        context.push('/settings/recurring');
        break;

      case ShortcutId.iouNotes:
        context.push('/balances');
        break;

      case ShortcutId.splitCalculator:
        SplitCalculatorSheet.show(context);
        break;

      case ShortcutId.exportCsv:
        context.push('/settings');
        break;

      case ShortcutId.backup:
        context.push('/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final list = _shortcuts.isNotEmpty
        ? _shortcuts
        : ShortcutEngine.rankShortcuts({});

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < list.length; i++) ...[
          Expanded(
            child: _buildShortcutTile(list[i], theme),
          ),
          if (i < list.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _buildShortcutTile(ShortcutDefinition def, SettlivThemeExtension theme) {
    return Semantics(
      button: true,
      label: def.label,
      child: InkWell(
        onTap: () => _onShortcutTapped(def),
        borderRadius: BorderRadius.circular(16),
        splashColor: theme.transparent,
        highlightColor: theme.transparent,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 44px rounded-16 icon tile
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.hairline),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadow.withOpacity(theme.isDark ? 0.25 : 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  def.icon,
                  size: 20,
                  color: theme.ink,
                ),
              ),
              const SizedBox(height: 6),
              // 11px label, max 2 lines, no capsules
              Text(
                def.label,
                style: AppTypography.caption.copyWith(
                  color: theme.ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
