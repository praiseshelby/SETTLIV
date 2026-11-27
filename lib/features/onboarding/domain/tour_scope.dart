import 'package:flutter/material.dart';

class TourAddController {
  void Function(String text)? setQuickText;
  void Function(int tabIndex)? setTab;
}

class TourScope extends InheritedWidget {
  final GlobalKey homeHeroKey;
  final GlobalKey homeAttentionKey;
  final GlobalKey addQuickInputKey;
  final GlobalKey addSplitModesKey;
  final GlobalKey groupBalancesKey;
  final GlobalKey groupSettleKey;
  final GlobalKey recordsEntryKey;
  final GlobalKey insightsBudgetKey;
  final TourAddController addController;
  final void Function(String route)? onInterceptRoute;

  TourScope({
    super.key,
    required this.homeHeroKey,
    required this.homeAttentionKey,
    required this.addQuickInputKey,
    required this.addSplitModesKey,
    GlobalKey? groupBalancesKey,
    GlobalKey? groupSettleKey,
    GlobalKey? recordsEntryKey,
    GlobalKey? insightsBudgetKey,
    required this.addController,
    this.onInterceptRoute,
    required super.child,
  })  : groupBalancesKey = groupBalancesKey ?? GlobalKey(),
        groupSettleKey = groupSettleKey ?? GlobalKey(),
        recordsEntryKey = recordsEntryKey ?? GlobalKey(),
        insightsBudgetKey = insightsBudgetKey ?? GlobalKey();

  static TourScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TourScope>();

  @override
  bool updateShouldNotify(covariant TourScope oldWidget) => false;
}
