import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/balance_hero_card.dart';
import '../../core/widgets/balance_pill.dart';
import '../../core/widgets/category_badge.dart';
import '../../core/widgets/coming_soon_tag.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/expense_tile.dart';
import '../../core/widgets/floating_add_button.dart';
import '../../core/widgets/group_card.dart';
import '../../core/widgets/group_cover_art.dart';
import '../../core/widgets/member_chip.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/person_avatar.dart';
import '../../core/widgets/avatar_stack.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/segmented_tabs.dart';
import '../../core/widgets/sheet_scaffold.dart';
import '../../core/widgets/text_action_button.dart';
import '../../core/widgets/undo_snackbar.dart';
import '../../data/models/expense.dart';
import '../../data/models/group.dart';
import '../../data/seed/seed_data.dart';

class ComponentGalleryScreen extends ConsumerStatefulWidget {
  const ComponentGalleryScreen({super.key});

  @override
  ConsumerState<ComponentGalleryScreen> createState() =>
      _ComponentGalleryScreenState();
}

class _ComponentGalleryScreenState
    extends ConsumerState<ComponentGalleryScreen> {
  int _selectedTab = 0;
  bool _chipSelected = true;

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final isDark = context.isDarkMode;
    final currentThemeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: theme.canvas,
      appBar: AppBar(
        title: Text(
          'Component Gallery',
          style: AppTypography.titleLarge.copyWith(color: theme.ink),
        ),
        backgroundColor: theme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: theme.ink,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () {
              ref.read(themeModeProvider.notifier).setThemeMode(
                    isDark ? ThemeMode.light : ThemeMode.dark,
                  );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          Text(
            'Mode: ${currentThemeMode.name.toUpperCase()} (System / Light / Dark)',
            style: AppTypography.caption.copyWith(color: theme.secondary),
          ),
          const SizedBox(height: 16),

          // 1. MoneyText
          const SectionHeader(title: '1. MoneyText'),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: const [
              MoneyText(paise: 124000, colorRole: MoneyColorRole.emerald, showSign: true),
              MoneyText(paise: -38000, colorRole: MoneyColorRole.coral, showSign: true),
              MoneyText(paise: 1800000, colorRole: MoneyColorRole.ink),
              MoneyText(paise: 0, colorRole: MoneyColorRole.secondary),
            ],
          ),
          const SizedBox(height: 24),

          // 2. BalanceHeroCard
          const SectionHeader(title: '2. BalanceHeroCard'),
          const BalanceHeroCard(
            netPaise: 86000, // +₹860
            totalOwedToUserPaise: 124000, // ₹1,240
            totalUserOwesPaise: 38000, // ₹380
          ),
          const SizedBox(height: 24),

          // 3. BalancePill
          const SectionHeader(title: '3. BalancePill'),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: const [
              BalancePill(paise: 124000),
              BalancePill(paise: -38000),
              BalancePill(paise: 0),
              BalancePill(paise: 50000, compact: true),
              BalancePill(paise: -25000, compact: true),
            ],
          ),
          const SizedBox(height: 24),

          // 4. PersonAvatar & AvatarStack
          const SectionHeader(title: '4. Avatars & Duotones'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < AppColors.avatarGradients.length; i++)
                PersonAvatar(
                  initials: 'P$i',
                  gradientIndex: i,
                  size: 38,
                ),
            ],
          ),
          const SizedBox(height: 12),
          AvatarStack(
            people: SeedData.people,
            size: 32,
            overlap: 10,
          ),
          const SizedBox(height: 24),

          // 5. GroupCoverArt
          const SectionHeader(title: '5. GroupCoverArt (CustomPainter)'),
          const Text('Flatmates Cover Art:'),
          const SizedBox(height: 6),
          const GroupCoverArt(
            coverType: GroupCoverType.flatmates,
            height: 90,
          ),
          const SizedBox(height: 12),
          const Text('Goa Trip Cover Art:'),
          const SizedBox(height: 6),
          const GroupCoverArt(
            coverType: GroupCoverType.goaTrip,
            height: 90,
          ),
          const SizedBox(height: 24),

          // 6. GroupCard
          const SectionHeader(title: '6. GroupCard'),
          GroupCard(
            group: SeedData.flatmates,
            members: [SeedData.arjun, SeedData.meera, SeedData.kabir],
            userNetPaise: 124000,
            onTap: () {},
          ),
          const SizedBox(height: 12),
          GroupCard(
            group: SeedData.goaTrip,
            members: [
              SeedData.arjun,
              SeedData.nisha,
              SeedData.rohan,
              SeedData.tara,
            ],
            userNetPaise: -38000,
            onTap: () {},
          ),
          const SizedBox(height: 24),

          // 7. CategoryBadge
          const SectionHeader(title: '7. CategoryBadges (8 Categories)'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final cat in ExpenseCategory.values)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CategoryBadge(category: cat, size: 44),
                    const SizedBox(height: 4),
                    Text(
                      cat.label,
                      style: AppTypography.caption.copyWith(
                        color: theme.secondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 24),

          // 8. ExpenseTile
          const SectionHeader(title: '8. ExpenseTile'),
          ExpenseTile(
            expense: SeedData.expenses.first,
            payer: SeedData.meera,
            group: SeedData.flatmates,
            currentUserId: SeedData.currentUserId,
            onTap: () {},
          ),
          ExpenseTile(
            expense: SeedData.expenses[1],
            payer: SeedData.arjun,
            group: SeedData.flatmates,
            currentUserId: SeedData.currentUserId,
            onTap: () {},
          ),
          const SizedBox(height: 24),

          // 9. MemberChip
          const SectionHeader(title: '9. MemberChip'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              MemberChip(
                person: SeedData.arjun,
                isSelected: _chipSelected,
                onSelected: (val) => setState(() => _chipSelected = val),
              ),
              MemberChip(
                person: SeedData.meera,
                isSelected: !_chipSelected,
                onSelected: (val) => setState(() => _chipSelected = !val),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 10. SegmentedTabs
          const SectionHeader(title: '10. SegmentedTabs'),
          SegmentedTabs(
            labels: const ['Quick', 'Manual'],
            selectedIndex: _selectedTab,
            onTabSelected: (idx) => setState(() => _selectedTab = idx),
          ),
          const SizedBox(height: 24),

          // 11. Buttons
          const SectionHeader(title: '11. Buttons & Actions'),
          PrimaryButton(
            label: 'Primary Navy Button',
            onPressed: () {},
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'Mark Paid (Confirm Emerald)',
            variant: PrimaryButtonVariant.emeraldConfirm,
            onPressed: () {},
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'Secondary Button',
            onPressed: () {},
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextActionButton(
                label: 'Cobalt Action',
                onPressed: () {},
              ),
              const SizedBox(width: 12),
              TextActionButton(
                label: 'Delete (Destructive)',
                variant: TextActionButtonVariant.destructive,
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 12. ComingSoonTag
          const SectionHeader(title: '12. ComingSoonTag & Sheet'),
          Wrap(
            spacing: 8,
            children: const [
              ComingSoonTag(label: 'Scan a receipt · full app'),
              ComingSoonTag(label: 'Nudge reminders'),
            ],
          ),
          const SizedBox(height: 24),

          // 13. UndoSnackbar trigger
          const SectionHeader(title: '13. UndoSnackbar'),
          SecondaryButton(
            label: 'Show UndoSnackbar',
            onPressed: () {
              UndoSnackbar.show(
                context: context,
                message: 'Added ₹800 · Undo',
                onUndo: () {},
              );
            },
          ),
          const SizedBox(height: 24),

          // 14. SheetScaffold trigger
          const SectionHeader(title: '14. SheetScaffold'),
          SecondaryButton(
            label: 'Open SheetScaffold Demo',
            onPressed: () {
              SheetScaffold.show(
                context: context,
                builder: (ctx) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'This is a SheetScaffold with 28px top corners, grab handle, and dismiss button.',
                        style: AppTypography.body
                            .copyWith(color: ctx.settliv.ink),
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: 'Close Sheet',
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // 15. EmptyState
          const SectionHeader(title: '15. EmptyState'),
          const EmptyState(
            title: 'No expenses yet',
            subtitle: 'Expenses added to this group will appear here.',
          ),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingAddButton(
        onTap: () {
          UndoSnackbar.show(
            context: context,
            message: 'FloatingAddButton tapped',
            onUndo: () {},
          );
        },
      ),
    );
  }
}
