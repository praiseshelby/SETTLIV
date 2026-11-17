import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/avatar_stack.dart';
import '../../core/widgets/balance_hero_card.dart';
import '../../core/widgets/balance_pill.dart';
import '../../core/widgets/category_badge.dart';
import '../../core/widgets/floating_add_pill.dart';
import '../../core/widgets/glass_chip.dart';
import '../../core/widgets/glass_segmented.dart';
import '../../core/widgets/glass_sheet_scaffold.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/gradient_primary_button.dart';
import '../../core/widgets/group_cover_art.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/person_avatar.dart';
import '../../core/widgets/section_header.dart';
import '../../data/models/expense.dart';
import '../../data/seed/seed_data.dart';

class ComponentGalleryScreen extends ConsumerStatefulWidget {
  const ComponentGalleryScreen({super.key});

  @override
  ConsumerState<ComponentGalleryScreen> createState() =>
      _ComponentGalleryScreenState();
}

class _ComponentGalleryScreenState
    extends ConsumerState<ComponentGalleryScreen> {
  int _selectedSegment = 0;
  bool _chipSelected = true;

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final isDark = context.isDarkMode;
    final currentThemeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              // Top Bar with Theme Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Component Gallery v2',
                    style: AppTypography.titleLarge.copyWith(color: theme.ink),
                  ),
                  IconButton(
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
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
              Text(
                'Theme: ${currentThemeMode.name.toUpperCase()} (Pearl Glass / Midnight Glass)',
                style: AppTypography.caption.copyWith(color: theme.secondary),
              ),
              const SizedBox(height: 24),

              // 1. GlassSurface (3 levels)
              const SectionHeader(title: '1. GlassSurface (Levels 1, 2, 3)'),
              const SizedBox(height: 8),
              GlassSurface(
                level: GlassLevel.level1,
                padding: const EdgeInsets.all(16),
                child: Text('Level 1: Sub-card / Inner container',
                    style: AppTypography.body.copyWith(color: theme.ink)),
              ),
              const SizedBox(height: 12),
              GlassSurface(
                level: GlassLevel.level2,
                padding: const EdgeInsets.all(16),
                child: Text('Level 2: Standard Card / Composer',
                    style: AppTypography.body.copyWith(color: theme.ink)),
              ),
              const SizedBox(height: 12),
              GlassSurface(
                level: GlassLevel.level3,
                padding: const EdgeInsets.all(16),
                child: Text('Level 3: Hero / Sheet / Sticky bar',
                    style: AppTypography.body.copyWith(color: theme.ink)),
              ),
              const SizedBox(height: 24),

              // 2. Buttons & Pills
              const SectionHeader(title: '2. Buttons & Pills'),
              const SizedBox(height: 8),
              GradientPrimaryButton(
                label: 'Sapphire Primary CTA',
                onPressed: () {},
                icon: const Icon(Icons.bolt_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(height: 12),
              Center(
                child: FloatingAddPill(
                  label: 'Add',
                  onTap: () {},
                ),
              ),
              const SizedBox(height: 24),

              // 3. GlassSegmented (sliding thumb) & Chips
              const SectionHeader(title: '3. GlassSegmented & GlassChip'),
              const SizedBox(height: 8),
              GlassSegmented<int>(
                values: const [0, 1, 2],
                labels: const ['Quick', 'Manual', 'Recent'],
                selectedValue: _selectedSegment,
                onValueChanged: (v) => setState(() => _selectedSegment = v),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  GlassChip(
                    label: 'Rent 18,000',
                    isSelected: _chipSelected,
                    onTap: () =>
                        setState(() => _chipSelected = !_chipSelected),
                  ),
                  GlassChip(
                    label: 'Cab 240 with Kabir',
                    isSelected: false,
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 4. MoneyText v2 & BalancePill
              const SectionHeader(title: '4. MoneyText & BalancePill'),
              const SizedBox(height: 8),
              const MoneyText(paise: 86000, style: MoneyStyle.hero),
              const SizedBox(height: 8),
              const Row(
                children: [
                  BalancePill(paise: 124000),
                  SizedBox(width: 8),
                  BalancePill(paise: -38000),
                  SizedBox(width: 8),
                  BalancePill(paise: 0),
                ],
              ),
              const SizedBox(height: 24),

              // 5. Avatars & CategoryTiles
              const SectionHeader(title: '5. PersonAvatar & CategoryTiles'),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final p in SeedData.people.take(4)) ...[
                    PersonAvatar(person: p, size: 36),
                    const SizedBox(width: 8),
                  ],
                  const SizedBox(width: 12),
                  AvatarStack(people: SeedData.people, avatarSize: 32),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final cat in ExpenseCategory.values)
                    CategoryTile(category: cat, size: 40, iconSize: 20),
                ],
              ),
              const SizedBox(height: 24),

              // 6. GroupCoverArt v2
              const SectionHeader(title: '6. GroupCoverArt v2 (84px short banners)'),
              const SizedBox(height: 8),
              GroupCoverArt(group: SeedData.flatmates, height: 84),
              const SizedBox(height: 12),
              GroupCoverArt(group: SeedData.goaTrip, height: 84),
              const SizedBox(height: 24),

              // 7. BalanceHeroCard
              const SectionHeader(title: '7. BalanceHeroCard (Level 3 Glass)'),
              const SizedBox(height: 8),
              const BalanceHeroCard(
                netPaise: 86000,
                totalOwedToUserPaise: 124000,
                totalUserOwesPaise: 38000,
              ),
              const SizedBox(height: 24),

              // 8. GlassSheetScaffold preview
              const SectionHeader(title: '8. GlassSheetScaffold'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  GlassSheetScaffold.show(
                    context: context,
                    title: 'Sample Glass Sheet',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'This is rendered inside a GlassSheetScaffold with 32px top radius and backdrop blur.',
                        style: AppTypography.body.copyWith(color: theme.ink),
                      ),
                    ),
                  );
                },
                child: const Text('Open Glass Sheet'),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
