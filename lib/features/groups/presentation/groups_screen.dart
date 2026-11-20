import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/aurora_background.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_primary_button.dart';
import '../../../core/widgets/group_card.dart';
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewGroupSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final repo = ref.watch(appRepositoryProvider);
    final groups = ref.watch(allGroupsProvider);
    final people = ref.watch(allPeopleProvider);
    final currentUserId = repo.currentUserId;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            children: [
              // Header Row: Title + "New Group" Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Groups',
                          style: AppTypography.titleLarge.copyWith(
                            color: theme.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 26,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${groups.length} active ${groups.length == 1 ? 'group' : 'groups'}',
                          style: AppTypography.caption.copyWith(
                            color: theme.secondary,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'Create new group',
                    child: InkWell(
                      onTap: () => _openNewGroupSheet(context),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.sapphire,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.sapphire.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_rounded,
                                size: 18, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'New group',
                              style: AppTypography.chip.copyWith(
                                color: Colors.white,
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
              const SizedBox(height: 24),

              // Groups List or Empty State
              if (groups.isEmpty) ...[
                EmptyState(
                  title: 'No groups yet',
                  subtitle:
                      'Create a group for trips, housemates, or events to start tracking balances.',
                  action: ElevatedButton.icon(
                    onPressed: () => _openNewGroupSheet(context),
                    icon: const Icon(Icons.group_add_rounded),
                    label: const Text('Create a group'),
                  ),
                ),
              ] else ...[
                for (final group in groups) ...[
                  GroupCard(
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
                  const SizedBox(height: 16),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NewGroupSheet extends ConsumerStatefulWidget {
  const _NewGroupSheet();

  @override
  ConsumerState<_NewGroupSheet> createState() => _NewGroupSheetState();
}

class _NewGroupSheetState extends ConsumerState<_NewGroupSheet> {
  final _nameController = TextEditingController();
  final _memberInputController = TextEditingController();
  GroupType _selectedType = GroupType.trip;
  final List<String> _memberNames = [];
  String? _nameError;
  String? _memberError;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(appRepositoryProvider);
    final currentUserName = repo.currentUser?.name ?? 'You';
    _memberNames.add(currentUserName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _memberInputController.dispose();
    super.dispose();
  }

  void _addMember() {
    final rawName = _memberInputController.text.trim();
    if (rawName.isEmpty) return;

    if (_memberNames.any((m) => m.toLowerCase() == rawName.toLowerCase())) {
      setState(() => _memberError = 'Member "$rawName" is already added');
      return;
    }

    setState(() {
      _memberNames.add(rawName);
      _memberInputController.clear();
      _memberError = null;
    });
  }

  void _removeMember(int index) {
    if (index == 0) return; // Keep currentUser
    setState(() {
      _memberNames.removeAt(index);
    });
  }

  void _submit() {
    final repo = ref.read(appRepositoryProvider);
    final allGroups = repo.getGroups();
    final name = _nameController.text.trim();

    // Validation 1: Name required
    if (name.isEmpty) {
      setState(() => _nameError = 'Group name is required');
      return;
    }

    // Validation 2: Name unique (case-insensitive)
    if (allGroups.any((g) => g.name.toLowerCase() == name.toLowerCase())) {
      setState(() => _nameError = 'A group named "$name" already exists');
      return;
    }

    // Validation 3: At least 2 members
    if (_memberNames.length < 2) {
      setState(() => _memberError = 'Add at least one more member');
      return;
    }

    final repoNotifier = ref.read(appStateProvider.notifier);
    final List<String> memberIds = [];

    // Ensure all members exist as Person objects
    final allPeople = repo.getPeople();
    for (final mName in _memberNames) {
      final existing = allPeople.cast<Person?>().firstWhere(
            (p) => p?.name.toLowerCase() == mName.toLowerCase(),
            orElse: () => null,
          );
      if (existing != null) {
        memberIds.add(existing.id);
      } else {
        final newId = 'person_${DateTime.now().millisecondsSinceEpoch}_${memberIds.length}';
        final initials = mName.isNotEmpty
            ? mName.substring(0, math.min(2, mName.length)).toUpperCase()
            : '??';
        final newPerson = Person(
          id: newId,
          name: mName,
          avatarInitials: initials,
          avatarPairIndex: memberIds.length % 8,
        );
        repoNotifier.addPerson(newPerson);
        memberIds.add(newId);
      }
    }

    final newGroupId = 'group_${DateTime.now().millisecondsSinceEpoch}';
    final newGroup = Group(
      id: newGroupId,
      name: name,
      type: _selectedType,
      memberIds: memberIds,
      coverType: _selectedType == GroupType.trip
          ? GroupCoverType.goaTrip
          : GroupCoverType.flatmates,
    );

    repoNotifier.addGroup(newGroup);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Created "$name" group!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: theme.hairline),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sheet Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Create new group',
                    style: AppTypography.titleLarge.copyWith(
                      color: theme.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Group Name Input
              Text(
                'GROUP NAME',
                style: AppTypography.sectionLabel.copyWith(
                  color: theme.secondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.ink,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Manali Roadtrip, Apartment 4B',
                  hintStyle: TextStyle(
                    fontFamily: 'Manrope',
                    color: theme.secondary.withValues(alpha: 0.6),
                  ),
                  filled: true,
                  fillColor: theme.raised,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.hairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.hairline),
                  ),
                  errorText: _nameError,
                ),
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
              ),
              const SizedBox(height: 16),

              // Group Type Selector: Trip / Home / Other
              Text(
                'GROUP TYPE',
                style: AppTypography.sectionLabel.copyWith(
                  color: theme.secondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildTypeChip('Trip', GroupType.trip, Icons.flight_takeoff_rounded),
                  const SizedBox(width: 8),
                  _buildTypeChip('Home', GroupType.home, Icons.home_rounded),
                  const SizedBox(width: 8),
                  _buildTypeChip('Other', GroupType.other, Icons.category_rounded),
                ],
              ),
              const SizedBox(height: 20),

              // Members
              Text(
                'MEMBERS (MIN 2)',
                style: AppTypography.sectionLabel.copyWith(
                  color: theme.secondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),

              // Member Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < _memberNames.length; i++)
                    Chip(
                      label: Text(
                        _memberNames[i],
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: theme.ink,
                        ),
                      ),
                      backgroundColor: theme.raised,
                      side: BorderSide(color: theme.hairline),
                      deleteIcon: i > 0
                          ? const Icon(Icons.close_rounded, size: 16)
                          : null,
                      onDeleted: i > 0 ? () => _removeMember(i) : null,
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Add member input field + button
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _memberInputController,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        color: theme.ink,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Add friend name...',
                        hintStyle: TextStyle(
                          fontFamily: 'Manrope',
                          color: theme.secondary.withValues(alpha: 0.6),
                        ),
                        filled: true,
                        fillColor: theme.raised,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
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
                      backgroundColor: AppColors.sapphire,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
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
                  style: const TextStyle(
                    color: AppColors.coral,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Submit button
              GradientPrimaryButton(
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
              color: isSelected
                  ? AppColors.sapphire.withValues(alpha: 0.15)
                  : theme.raised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.sapphire : theme.hairline,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? AppColors.sapphire : theme.secondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.sapphire : theme.ink,
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
