import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/segmented_tabs.dart';

class AddExpensePlaceholderScreen extends StatefulWidget {
  const AddExpensePlaceholderScreen({super.key});

  @override
  State<AddExpensePlaceholderScreen> createState() =>
      _AddExpensePlaceholderScreenState();
}

class _AddExpensePlaceholderScreenState
    extends State<AddExpensePlaceholderScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    return Scaffold(
      backgroundColor: theme.canvas,
      appBar: AppBar(
        backgroundColor: theme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: theme.ink),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Add expense',
          style: AppTypography.titleLarge.copyWith(color: theme.ink),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedTabs(
                labels: const ['Quick', 'Manual'],
                selectedIndex: _selectedTab,
                onTabSelected: (idx) => setState(() => _selectedTab = idx),
              ),
              const Spacer(),
              Center(
                child: Text(
                  'Add Expense will be built in Part 2',
                  style: AppTypography.body.copyWith(color: theme.secondary),
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Back to Home',
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
