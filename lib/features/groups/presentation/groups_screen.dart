import '../../../core/layout/adaptive_layout.dart';
import '../../../core/profile/experience_mode.dart';
import '../../../core/widgets/adaptive_presenter.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/group_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../data/models/group.dart';
import '../../../data/models/person.dart';
import '../../../data/repositories/in_memory_app_repository.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  void _openNewGroupSheet(BuildContext context) {
    AdaptivePresenter.show<void>(
      context: context,
      title: 'New group',
      type: PresentationType.formOrConfirmation,
      child: const _NewGroupSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final repo = ref.watch(appRepositoryProvider);
    final allGroups = ref.watch(allGroupsProvider);
    final groups = allGroups.where((g) => !g.isPersonal).toList();
    final people = ref.watch(allPeopleProvider);
    final currentUserId = repo.currentUserId;

    return ScreenScaffold(
      header: ScreenHeader(
        title: 'Groups',
        subtitle: Text(
          '${groups.length} active ${groups.length == 1 ? 'group' : 'groups'}',
          style: AppTypography.caption.copyWith(
            color: theme.muted,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        actions: [
          Semantics(
            button: true,
            label: 'Create new group',
            child: InkWell(
              onTap: () => _openNewGroupSheet(context),
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
              // Group List or Empty State
              if (groups.isEmpty) ...[
                EmptyState(
                  title: 'No groups yet',
                  subtitle:
                      'Create a group for your apartment, trip, or shared expenses to start splitting.',
                  action: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryButtonBg,
                      foregroundColor: theme.primaryButtonText,
                    ),
                    onPressed: () => _openNewGroupSheet(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create a group'),
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
                          final cardWidth = (constraints.maxWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: groups.map((group) {
                              return SizedBox(
                                width: cardWidth,
                                child: GroupCard(
                                  group: group,
                                  members: people
                                      .where((p) => group.memberIds.contains(p.id))
                                      .toList(),
                                  userNetPaise: repo
                                          .getGroupSummary(group.id)
                                          .netBalances[currentUserId] ??
                                      0,
                                  onTap: () => context.push('/group/${group.id}'),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      );
                    }

                    // Mobile / compact web: single list
                    return Column(
                      children: groups.map((group) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: GroupCard(
                            group: group,
                            members: people
                                .where((p) => group.memberIds.contains(p.id))
                                .toList(),
                            userNetPaise: repo
                                    .getGroupSummary(group.id)
                                    .netBalances[currentUserId] ??
                                0,
                            onTap: () => context.push('/group/${group.id}'),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _NewGroupSheet extends ConsumerStatefulWidget {
  const _NewGroupSheet();

  @override
  ConsumerState<_NewGroupSheet> createState() => _NewGroupSheetState();
}

class _NewGroupSheetState extends ConsumerState<_NewGroupSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _memberController = TextEditingController();
  GroupType _selectedType = GroupType.trip;
  final List<String> _members = [];
  String? _nameError;
  String? _memberError;

  @override
  void dispose() {
    _nameController.dispose();
    _memberController.dispose();
    super.dispose();
  }

  void _addMember() {
    final text = _memberController.text.trim();
    if (text.isEmpty) return;

    if (_members.any((m) => m.toLowerCase() == text.toLowerCase())) {
      setState(() => _memberError = 'Member already added');
      return;
    }

    setState(() {
      _members.add(text);
      _memberController.clear();
      _memberError = null;
    });
  }

  void _removeMember(int index) {
    setState(() => _members.removeAt(index));
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Group name is required');
      return;
    }

    final repo = ref.read(appRepositoryProvider);
    final notifier = ref.read(appStateProvider.notifier);
    final currentUserId = repo.currentUserId;

    final List<String> memberIds = [currentUserId];

    for (final memberName in _members) {
      final existing = repo.getPeople().where(
            (p) => p.name.toLowerCase() == memberName.toLowerCase(),
          );

      if (existing.isNotEmpty) {
        memberIds.add(existing.first.id);
      } else {
        final newId = 'person_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(999)}';
        final newPerson = Person(
          id: newId,
          name: memberName,
        );
        notifier.addPerson(newPerson);
        memberIds.add(newId);
      }
    }

    final newGroup = Group(
      id: 'group_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      type: _selectedType,
      memberIds: memberIds,
      coverThemeIndex: math.Random().nextInt(6),
      startDate: DateTime.now(),
    );

    notifier.addGroup(newGroup);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.hairline,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'New Group',
                style: AppTypography.titleLarge.copyWith(
                  color: theme.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),

              // Group Name Field
              TextField(
                controller: _nameController,
                style: TextStyle(
                  fontFamily: AppTypography.fontBody,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.ink,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Flat 402, Manali Trip',
                  hintStyle: TextStyle(
                    fontFamily: AppTypography.fontBody,
                    color: theme.muted,
                  ),
                  filled: true,
                  fillColor: theme.raised,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.hairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.hairline),
                  ),
                  errorText: _nameError,
                ),
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
              ),
              const SizedBox(height: 16),

              // Type Selector: Home / Trip / Other
              Row(
                children: [
                  _buildTypeChip('Trip', GroupType.trip, Icons.flight_takeoff_rounded),
                  const SizedBox(width: 8),
                  _buildTypeChip('Home', GroupType.home, Icons.home_rounded),
                  const SizedBox(width: 8),
                  _buildTypeChip('Other', GroupType.other, Icons.groups_rounded),
                ],
              ),
              const SizedBox(height: 18),

              // Members List & Field
              Text(
                'MEMBERS (You are included)',
                style: AppTypography.caption.copyWith(
                  color: theme.muted,
                  letterSpacing: 0.8,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),

              if (_members.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (int i = 0; i < _members.length; i++)
                      Chip(
                        label: Text(_members[i]),
                        backgroundColor: theme.raised,
                        labelStyle: TextStyle(
                          fontFamily: AppTypography.fontBody,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.ink,
                        ),
                        deleteIcon: Icon(Icons.close_rounded, size: 16, color: theme.muted),
                        onDeleted: () => _removeMember(i),
                        side: BorderSide(color: theme.hairline),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _memberController,
                      style: TextStyle(
                        fontFamily: AppTypography.fontBody,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.ink,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Add member by name...',
                        hintStyle: TextStyle(
                          fontFamily: AppTypography.fontBody,
                          color: theme.muted,
                        ),
                        filled: true,
                        fillColor: theme.raised,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.hairline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.hairline),
                        ),
                      ),
                      onSubmitted: (_) => _addMember(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addMember,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.navy,
                      foregroundColor: theme.onNavy,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Add'),
                  ),
                ],
              ),
              if (_memberError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _memberError!,
                  style: TextStyle(
                    color: theme.textCoral,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Submit button
              PrimaryButton(
                label: 'Create group',
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, GroupType type, IconData icon) {
    final isSelected = _selectedType == type;
    final theme = context.settliv;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        child: InkWell(
          onTap: () => setState(() => _selectedType = type),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? theme.navy : theme.raised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? theme.navy : theme.hairline,
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? theme.onNavy : theme.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTypography.fontBody,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? theme.onNavy : theme.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
