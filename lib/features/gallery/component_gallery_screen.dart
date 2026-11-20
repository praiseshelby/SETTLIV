import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/avatar_stack.dart';
import '../../core/widgets/balance_hero_card.dart';
import '../../core/widgets/balance_pill.dart';
import '../../core/widgets/category_badge.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/group_cover_art.dart';
import '../../core/widgets/person_avatar.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/section_header.dart';
import '../../data/models/expense.dart';
import '../../data/seed/seed_data.dart';

class ComponentGalleryScreen extends StatefulWidget {
  const ComponentGalleryScreen({super.key});

  @override
  State<ComponentGalleryScreen> createState() => _ComponentGalleryScreenState();
}

class _ComponentGalleryScreenState extends State<ComponentGalleryScreen> {
  @override
  Widget build(BuildContext context) {
    final currentTheme = context.settliv;

    return Scaffold(
      backgroundColor: currentTheme.canvas,
      appBar: AppBar(
        title: Text(
          'Component Gallery',
          style: AppTypography.screenTitle.copyWith(color: currentTheme.ink, fontSize: 20),
        ),
        backgroundColor: currentTheme.canvas,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: currentTheme.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Side-by-side Light & Dark Theme Design System Audit',
              style: AppTypography.body.copyWith(color: currentTheme.muted),
            ),
          ),
          const SizedBox(height: 16),

          // 1. Primary Buttons
          _buildSideBySide(
            title: '1. Primary Buttons (Navy in Light / Off-White in Dark)',
            builder: (ctx) => Column(
              children: [
                PrimaryButton(
                  label: 'Add ₹1,240 to Flatmates',
                  onPressed: () {},
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: 'Mark paid',
                  variant: PrimaryButtonVariant.emeraldConfirm,
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. Balance Hero Card
          _buildSideBySide(
            title: '2. Balance Hero Card (Deep Navy with cached mesh)',
            builder: (ctx) => const BalanceHeroCard(
              netPaise: 86000,
              totalOwedToUserPaise: 124000,
              totalUserOwesPaise: 38000,
            ),
          ),
          const SizedBox(height: 24),

          // 3. Balance Pills (No truncation)
          _buildSideBySide(
            title: '3. Balance Badges / Pills (Never truncated)',
            builder: (ctx) => const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                BalancePill(paise: 124000),
                BalancePill(paise: -38000),
                BalancePill(paise: 0),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. Group Cover Themes (0..5)
          _buildSideBySide(
            title: '4. Group Cover Art (Cached CustomPainter with 6 themes)',
            builder: (ctx) => Column(
              children: [
                for (int i = 0; i < 6; i++) ...[
                  GroupCoverArt(
                    coverThemeIndex: i,
                    height: 52,
                    borderRadius: 14,
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 5. Category Badges
          _buildSideBySide(
            title: '5. Category Badges (Token-driven tints)',
            builder: (ctx) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cat in ExpenseCategory.values)
                  CategoryBadge(category: cat, size: 36, iconSize: 18),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 6. Avatars & Overlap-safe AvatarStack
          _buildSideBySide(
            title: '6. Avatar Stack (TextPainter initials safe from overlap)',
            builder: (ctx) => Row(
              children: [
                AvatarStack(
                  people: SeedData.people,
                  avatarSize: 32,
                  overlap: 10,
                ),
                const SizedBox(width: 14),
                const PersonAvatar(person: SeedData.arjun, size: 32),
                const SizedBox(width: 6),
                const PersonAvatar(person: SeedData.meera, size: 32),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 7. GlassSurface (Levels 1, 2, 3)
          _buildSideBySide(
            title: '7. Surfaces (Separation by 1px hairline, no card blur)',
            builder: (ctx) => Column(
              children: [
                GlassSurface(
                  level: GlassLevel.level1,
                  padding: const EdgeInsets.all(12),
                  child: Text('Level 1: Inner container', style: TextStyle(color: ctx.settliv.ink)),
                ),
                const SizedBox(height: 8),
                GlassSurface(
                  level: GlassLevel.level2,
                  padding: const EdgeInsets.all(12),
                  child: Text('Level 2: Standard Card', style: TextStyle(color: ctx.settliv.ink)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 8. Font Specimen: Sora + Plus Jakarta Sans + ₹ Symbol
          _buildSideBySide(
            title: '8. Font Specimen: Sora (Titles/Money) & Plus Jakarta Sans (Body/₹)',
            builder: (ctx) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹860 Owed',
                  style: AppTypography.moneyLarge.copyWith(color: ctx.settliv.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹12,450.50 Hero Tabular',
                  style: AppTypography.moneyHero.copyWith(color: ctx.settliv.textEmerald, fontSize: 24),
                ),
                const SizedBox(height: 6),
                Text(
                  'Screen Title 28/700 Sora',
                  style: AppTypography.screenTitle.copyWith(color: ctx.settliv.ink, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  'Section Header 17/700 Sora',
                  style: AppTypography.sectionTitle.copyWith(color: ctx.settliv.ink, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  'Body 15/500 Plus Jakarta Sans with ₹ glyph rendering verified.',
                  style: AppTypography.body.copyWith(color: ctx.settliv.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSideBySide({
    required String title,
    required Widget Function(BuildContext) builder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Light Theme Column
            Expanded(
              child: Theme(
                data: AppTheme.light(),
                child: Builder(
                  builder: (ctx) => Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ctx.settliv.canvas,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ctx.settliv.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LIGHT',
                          style: TextStyle(
                            fontFamily: AppTypography.fontBody,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: ctx.settliv.muted,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        builder(ctx),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Dark Theme Column
            Expanded(
              child: Theme(
                data: AppTheme.dark(),
                child: Builder(
                  builder: (ctx) => Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ctx.settliv.canvas,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ctx.settliv.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DARK',
                          style: TextStyle(
                            fontFamily: AppTypography.fontBody,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: ctx.settliv.muted,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        builder(ctx),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
