import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_sheet_scaffold.dart';
import '../../../core/widgets/group_cover_art.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/group.dart';
import '../../../data/models/person.dart';
import '../../../data/repositories/in_memory_app_repository.dart';

class EditGroupSheet extends ConsumerStatefulWidget {
  final Group group;

  const EditGroupSheet({super.key, required this.group});

  static void show({
    required BuildContext context,
    required Group group,
  }) {
    GlassSheetScaffold.show(
      context: context,
      title: 'Edit group',
      isScrollControlled: true,
      child: EditGroupSheet(group: group),
    );
  }

  @override
  ConsumerState<EditGroupSheet> createState() => _EditGroupSheetState();
}

class _EditGroupSheetState extends ConsumerState<EditGroupSheet> {
  late TextEditingController _nameController;
  late TextEditingController _newMemberController;
  late int _selectedCoverThemeIndex;
  late GroupType _selectedType;
  late List<String> _memberIds;
  final List<Person> _newlyCreatedPeople = [];
  bool _isAddingMember = false;
  String? _nameError;

  static const List<String> _themeNames = [
    'Arcs',
    'Waves',
    'Contours',
    'Orbits',
    'Flatmates',
    'GoaTrip',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
    _newMemberController = TextEditingController();
    _selectedCoverThemeIndex = widget.group.coverThemeIndex.clamp(0, 5);
    _selectedType = widget.group.type;
    _memberIds = List.from(widget.group.memberIds);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _newMemberController.dispose();
    super.dispose();
  }

  void _onSave() {
    final trimmedName = _nameController.text.trim();
    if (trimmedName.isEmpty) {
      setState(() => _nameError = 'Group name cannot be empty');
      return;
    }

    final repoNotifier = ref.read(appStateProvider.notifier);

    // Add any newly created people
    for (final person in _newlyCreatedPeople) {
      repoNotifier.addPerson(person);
    }

    final updated = widget.group.copyWith(
      name: trimmedName,
      type: _selectedType,
      coverThemeIndex: _selectedCoverThemeIndex,
      memberIds: _memberIds,
    );

    repoNotifier.updateGroup(updated);

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Updated "${updated.name}"'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addNewMemberByName() {
    final name = _newMemberController.text.trim();
    if (name.isEmpty) return;

    final id = 'person_${DateTime.now().millisecondsSinceEpoch}_${name.toLowerCase().replaceAll(' ', '_')}';
    final initials = name.split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join().toUpperCase();
    final newPerson = Person(
      id: id,
      name: name,
      avatarInitials: initials.isEmpty ? '?' : initials,
      avatarPairIndex: _memberIds.length % 8,
    );

    setState(() {
      _newlyCreatedPeople.add(newPerson);
      _memberIds.add(newPerson.id);
      _newMemberController.clear();
      _isAddingMember = false;
    });
  }

  void _addExistingPerson(Person person) {
    if (!_memberIds.contains(person.id)) {
      setState(() {
        _memberIds.add(person.id);
        _isAddingMember = false;
      });
    }
  }

  void _removeMember(String personId) {
    final repo = ref.read(appRepositoryProvider);
    if (personId == repo.currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot remove yourself from the group'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _memberIds.remove(personId);
      _newlyCreatedPeople.removeWhere((p) => p.id == personId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final allPeople = ref.watch(allPeopleProvider);
    final repo = ref.watch(appRepositoryProvider);
    final currentUserId = repo.currentUserId;

    // Full list of people available (existing + newly staged)
    final combinedPeople = <Person>[...allPeople, ..._newlyCreatedPeople];
    final peopleMap = {for (final p in combinedPeople) p.id: p};

    final nonMembers = allPeople.where((p) => !_memberIds.contains(p.id)).toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Live Cover Art Preview
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                GroupCoverArt(
                  coverThemeIndex: _selectedCoverThemeIndex,
                  height: 100,
                  borderRadius: 18,
                ),
                Positioned(
                  left: 16,
                  bottom: 12,
                  right: 16,
                  child: Text(
                    _nameController.text.trim().isEmpty ? 'Group name' : _nameController.text.trim(),
                    style: AppTypography.titleLarge.copyWith(
                      color: theme.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(
                          color: theme.black.withValues(alpha: 0.6),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 1. Group Name Field
          Text(
            'GROUP NAME',
            style: AppTypography.caption.copyWith(
              color: theme.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: AppTypography.bodyMedium.copyWith(
              color: theme.ink,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Flat 402, Goa Trip',
              hintStyle: TextStyle(color: theme.muted),
              filled: true,
              fillColor: theme.raised,
              errorText: _nameError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: theme.hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: theme.hairline),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
              setState(() {});
            },
          ),
          const SizedBox(height: 18),

          // 2. Cover Theme Selector (6 themes)
          Text(
            'COVER THEME',
            style: AppTypography.caption.copyWith(
              color: theme.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < 6; i++) ...[
                  InkWell(
                    onTap: () => setState(() => _selectedCoverThemeIndex = i),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 58,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      decoration: BoxDecoration(
                        color: theme.raised,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedCoverThemeIndex == i ? theme.navy : theme.hairline,
                          width: _selectedCoverThemeIndex == i ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 32,
                            width: 46,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: LinearGradient(
                                colors: theme.coverThemePalettes[i].take(2).toList(),
                              ),
                            ),
                            child: _selectedCoverThemeIndex == i
                                ? Icon(Icons.check_rounded, color: theme.white, size: 18)
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _themeNames[i],
                            style: AppTypography.caption.copyWith(
                              color: _selectedCoverThemeIndex == i ? theme.ink : theme.muted,
                              fontSize: 10,
                              fontWeight: _selectedCoverThemeIndex == i ? FontWeight.w700 : FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 3. Group Type (Home, Trip, Other)
          Text(
            'GROUP TYPE',
            style: AppTypography.caption.copyWith(
              color: theme.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final type in GroupType.values) ...[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      onTap: () => setState(() => _selectedType = type),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedType == type
                              ? theme.navy.withValues(alpha: 0.15)
                              : theme.raised,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedType == type ? theme.navy : theme.hairline,
                            width: _selectedType == type ? 1.5 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          type.label,
                          style: AppTypography.caption.copyWith(
                            color: _selectedType == type ? theme.ink : theme.muted,
                            fontWeight: _selectedType == type ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),

          // 4. Members Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MEMBERS (${_memberIds.length})',
                style: AppTypography.caption.copyWith(
                  color: theme.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              if (!_isAddingMember)
                InkWell(
                  onTap: () => setState(() => _isAddingMember = true),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_add_alt_1_rounded, size: 14, color: theme.navy),
                        const SizedBox(width: 4),
                        Text(
                          'Add member',
                          style: AppTypography.caption.copyWith(
                            color: theme.isDark ? theme.ink : theme.navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Add Member inline form if active
          if (_isAddingMember) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.raised,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newMemberController,
                          autofocus: true,
                          style: TextStyle(color: theme.ink, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Enter name for new person',
                            hintStyle: TextStyle(color: theme.muted, fontSize: 13),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: theme.hairline),
                            ),
                          ),
                          onSubmitted: (_) => _addNewMemberByName(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryButtonBg,
                          foregroundColor: theme.primaryButtonText,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _addNewMemberByName,
                        child: const Text('Add'),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(Icons.close_rounded, size: 18, color: theme.muted),
                        onPressed: () => setState(() => _isAddingMember = false),
                      ),
                    ],
                  ),
                  if (nonMembers.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Or pick from contacts:',
                      style: AppTypography.caption.copyWith(color: theme.muted, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final p in nonMembers) ...[
                          ActionChip(
                            avatar: PersonAvatar(person: p, size: 20),
                            label: Text(p.name, style: TextStyle(color: theme.ink, fontSize: 12)),
                            backgroundColor: theme.surface,
                            side: BorderSide(color: theme.hairline),
                            onPressed: () => _addExistingPerson(p),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Member List Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final memberId in _memberIds) ...[
                Builder(builder: (context) {
                  final p = peopleMap[memberId] ??
                      Person(
                        id: memberId,
                        name: 'Member',
                        avatarInitials: 'M',
                        avatarPairIndex: 0,
                      );
                  final isYou = p.id == currentUserId;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.raised,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: theme.hairline),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PersonAvatar(person: p, size: 22),
                        const SizedBox(width: 6),
                        Text(
                          isYou ? '${p.name} (You)' : p.name,
                          style: AppTypography.caption.copyWith(
                            color: theme.ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        if (!isYou) ...[
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => _removeMember(p.id),
                            borderRadius: BorderRadius.circular(999),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(Icons.close_rounded, size: 14, color: theme.muted),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // 5. Save Changes Button
          PrimaryButton(
            label: 'Save changes',
            onPressed: _onSave,
          ),
        ],
      ),
    );
  }
}
