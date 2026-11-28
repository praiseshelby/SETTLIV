import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/layout/adaptive_layout.dart';
import '../../../core/profile/experience_mode.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_segmented.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../data/models/group.dart';
import '../../../data/repositories/in_memory_app_repository.dart';
import '../../../data/repositories/sharing_repository.dart';
import 'widgets/create_edit_group_sheet.dart';
import 'widgets/group_hub_card.dart';
import 'widgets/join_and_invites_sheets.dart';

enum GroupSortOption {
  recent('Recent'),
  balance('Balance'),
  alphabetical('A-Z');

  final String label;
  const GroupSortOption(this.label);
}

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  int _selectedTab = 0; // 0 = Active, 1 = Archived
  GroupSortOption _sortOption = GroupSortOption.recent;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCreateGroupSheet({
    String? prefillName,
    GroupType? prefillType,
    int? prefillCoverIndex,
    String? prefillSplitMode,
  }) {
    CreateEditGroupSheet.show(
      context,
      prefillName: prefillName,
      prefillType: prefillType,
      prefillCoverThemeIndex: prefillCoverIndex,
      prefillSplitMode: prefillSplitMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final repo = ref.watch(appRepositoryProvider);
    final allGroups = ref.watch(allGroupsProvider);
    final sharedGroups = allGroups.where((g) => !g.isPersonal).toList();
    final people = ref.watch(allPeopleProvider);
    final allExpenses = ref.watch(allExpensesProvider);
    final currentUserId = repo.currentUserId;

    // Separate active and archived
    final activeGroups = sharedGroups.where((g) => !g.isArchived).toList();
    final archivedGroups = sharedGroups.where((g) => g.isArchived).toList();

    // Summary numbers for Active groups
    int totalOwedToUser = 0;
    int totalUserOwes = 0;
    for (final g in activeGroups) {
      final summary = repo.getGroupSummary(g.id);
      final net = summary.netBalances[currentUserId] ?? 0;
      if (net > 0) totalOwedToUser += net;
      if (net < 0) totalUserOwes += net.abs();
    }

    // Filter by tab
    var displayedGroups = _selectedTab == 0 ? activeGroups : archivedGroups;

    // Filter by search query
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      displayedGroups = displayedGroups.where((g) => g.name.toLowerCase().contains(query)).toList();
    }

    // Sort: Pinned first, then by selected option
    displayedGroups.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      switch (_sortOption) {
        case GroupSortOption.recent:
          final aExpenses = repo.getExpensesForGroup(a.id);
          final bExpenses = repo.getExpensesForGroup(b.id);
          final aLast = aExpenses.isNotEmpty
              ? aExpenses.map((e) => e.date).reduce((x, y) => x.isAfter(y) ? x : y)
              : (a.createdAt ?? DateTime(2024, 1, 1));
          final bLast = bExpenses.isNotEmpty
              ? bExpenses.map((e) => e.date).reduce((x, y) => x.isAfter(y) ? x : y)
              : (b.createdAt ?? DateTime(2024, 1, 1));
          return bLast.compareTo(aLast);
        case GroupSortOption.balance:
          final aNet = (repo.getGroupSummary(a.id).netBalances[currentUserId] ?? 0).abs();
          final bNet = (repo.getGroupSummary(b.id).netBalances[currentUserId] ?? 0).abs();
          return bNet.compareTo(aNet);
        case GroupSortOption.alphabetical:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });

    return ScreenScaffold(
      header: ScreenHeader(
        title: 'Groups',
        subtitle: Text(
          '${activeGroups.length} active ${activeGroups.length == 1 ? 'group' : 'groups'}',
          style: AppTypography.caption.copyWith(
            color: theme.muted,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        actions: [
          // Invites inbox button
          Consumer(
            builder: (context, ref, _) {
              final count = ref
                      .watch(incomingInvitesProvider)
                      .valueOrNull
                      ?.length ??
                  0;
              return IconButton(
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: Icon(
                    Icons.mail_outline_rounded,
                    size: 20,
                    color: theme.ink,
                  ),
                ),
                tooltip: 'Group invites',
                onPressed: () => InvitesInboxSheet.show(context),
              );
            },
          ),
          // Join by code button
          IconButton(
            icon: Icon(Icons.qr_code_rounded, size: 20, color: theme.ink),
            tooltip: 'Join with code',
            onPressed: () => JoinGroupSheet.show(context),
          ),
          // Search toggle button
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, size: 20),
            color: theme.ink,
            tooltip: _isSearching ? 'Close search' : 'Search groups',
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchController.clear();
              });
            },
          ),
          const SizedBox(width: 4),
          // New group action
          Semantics(
            button: true,
            label: 'Create new group',
            child: InkWell(
              onTap: () => _openCreateGroupSheet(),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.primaryButtonBg,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadow.withValues(alpha: theme.isDark ? 0.3 : 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 18, color: theme.primaryButtonText),
                    const SizedBox(width: 4),
                    Text(
                      'New group',
                      style: AppTypography.chip.copyWith(
                        color: theme.primaryButtonText,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search input if open
              if (_isSearching) ...[
                GlassSurface(
                  level: GlassLevel.level1,
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 18, color: theme.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: AppTypography.bodyMedium.copyWith(color: theme.ink),
                          decoration: InputDecoration(
                            hintText: 'Search groups by name...',
                            hintStyle: AppTypography.body.copyWith(color: theme.tertiary),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() => _searchController.clear()),
                          child: Icon(Icons.clear_rounded, size: 16, color: theme.muted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 1. Summary Strip (Owed to you / You owe / Active groups)
              GlassSurface(
                level: GlassLevel.level1,
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Owed to you', style: AppTypography.caption.copyWith(color: theme.muted, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.formatPaise(totalOwedToUser),
                            style: TextStyle(
                              fontFamily: AppTypography.fontDisplay,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: theme.textEmerald,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 32, color: theme.hairline),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('You owe', style: AppTypography.caption.copyWith(color: theme.muted, fontSize: 11)),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyFormatter.formatPaise(totalUserOwes),
                              style: TextStyle(
                                fontFamily: AppTypography.fontDisplay,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: theme.textCoral,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(width: 1, height: 32, color: theme.hairline),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Active', style: AppTypography.caption.copyWith(color: theme.muted, fontSize: 11)),
                            const SizedBox(height: 2),
                            Text(
                              '${activeGroups.length}',
                              style: TextStyle(
                                fontFamily: AppTypography.fontDisplay,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: theme.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Tab Bar: Active | Archived + Sort Menu
              Row(
                children: [
                  Expanded(
                    child: GlassSegmented<int>(
                      values: const [0, 1],
                      labels: [
                        'Active (${activeGroups.length})',
                        'Archived (${archivedGroups.length})',
                      ],
                      selectedValue: _selectedTab,
                      onValueChanged: (val) => setState(() => _selectedTab = val),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Sort Menu
                  Container(
                    decoration: BoxDecoration(
                      color: theme.surface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: theme.hairline),
                    ),
                    child: PopupMenuButton<GroupSortOption>(
                      icon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sort_rounded, size: 16, color: theme.ink),
                          const SizedBox(width: 4),
                          Text(
                            _sortOption.label,
                            style: AppTypography.caption.copyWith(
                              color: theme.ink,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                          Icon(Icons.arrow_drop_down_rounded, size: 16, color: theme.muted),
                        ],
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: theme.raised,
                      onSelected: (opt) => setState(() => _sortOption = opt),
                      itemBuilder: (ctx) => GroupSortOption.values.map((opt) {
                        return PopupMenuItem(
                          value: opt,
                          child: Text(opt.label, style: TextStyle(color: theme.ink, fontSize: 13)),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 3. Group Grid / List or Empty State
              if (displayedGroups.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: EmptyState(
                    title: _selectedTab == 0 ? 'No active groups' : 'No archived groups',
                    subtitle: _selectedTab == 0
                        ? 'Create a group or pick a template below to start splitting.'
                        : 'Archived groups will appear here.',
                    action: _selectedTab == 0
                        ? ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primaryButtonBg,
                              foregroundColor: theme.primaryButtonText,
                            ),
                            onPressed: () => _openCreateGroupSheet(),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Create a group'),
                          )
                        : null,
                  ),
                ),
              ] else ...[
                Builder(
                  builder: (ctx) {
                    final effective = ref.watch(effectiveExperienceProvider);
                    final layout = AdaptiveLayout.of(ctx);

                    if (effective == EffectiveExperience.web && layout != LayoutClass.compact) {
                      final crossAxisCount = layout == LayoutClass.expanded ? 3 : 2;
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          const spacing = 16.0;
                          final cardWidth =
                              (constraints.maxWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: displayedGroups.map((group) {
                              return SizedBox(
                                width: cardWidth,
                                child: GroupHubCard(
                                  group: group,
                                  members: people.where((p) => group.memberIds.contains(p.id)).toList(),
                                  summary: repo.getGroupSummary(group.id),
                                  expenses: allExpenses.where((e) => e.groupId == group.id).toList(),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      );
                    }

                    // Mobile / compact web: vertical list
                    return Column(
                      children: displayedGroups.map((group) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: GroupHubCard(
                            group: group,
                            members: people.where((p) => group.memberIds.contains(p.id)).toList(),
                            summary: repo.getGroupSummary(group.id),
                            expenses: allExpenses.where((e) => e.groupId == group.id).toList(),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
              const SizedBox(height: 32),

              // 4. "Start a new group" with templates (Active tab only)
              if (_selectedTab == 0) ...[
                Text(
                  'START A NEW GROUP',
                  style: AppTypography.sectionLabel.copyWith(
                    color: theme.secondary,
                    letterSpacing: 0.8,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 10),
                _buildTemplatesRow(theme),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTemplatesRow(SettlivThemeExtension theme) {
    const templates = [
      _GroupTemplate('Trip', Icons.flight_takeoff_rounded, GroupType.trip, 1, 'equal'),
      _GroupTemplate('Flatmates', Icons.home_rounded, GroupType.home, 0, 'equal'),
      _GroupTemplate('Couple', Icons.favorite_rounded, GroupType.couple, 2, 'equal'),
      _GroupTemplate('Event', Icons.celebration_rounded, GroupType.event, 3, 'equal'),
      _GroupTemplate('Friends', Icons.people_alt_rounded, GroupType.friends, 4, 'equal'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: templates.map((tmpl) {
          final palette = theme.coverThemePalettes[tmpl.coverIndex];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Semantics(
              button: true,
              label: '${tmpl.name} template',
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _openCreateGroupSheet(
                    prefillName: tmpl.name,
                    prefillType: tmpl.type,
                    prefillCoverIndex: tmpl.coverIndex,
                    prefillSplitMode: tmpl.splitMode,
                  );
                },
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 120,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.surface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.hairline),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: palette, begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(tmpl.icon, color: theme.white, size: 22),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tmpl.name,
                        style: AppTypography.bodySemiBold.copyWith(color: theme.ink, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tmpl.type.label,
                        style: AppTypography.caption.copyWith(color: theme.muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _GroupTemplate {
  final String name;
  final IconData icon;
  final GroupType type;
  final int coverIndex;
  final String splitMode;

  const _GroupTemplate(this.name, this.icon, this.type, this.coverIndex, this.splitMode);
}
