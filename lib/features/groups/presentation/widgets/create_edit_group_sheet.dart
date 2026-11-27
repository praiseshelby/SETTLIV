import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/guest_limit_sheet.dart';
import '../../../../core/auth/guest_limits.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/name_normalizer.dart';
import '../../../../core/widgets/adaptive_presenter.dart';
import '../../../../core/widgets/form_sheet_scaffold.dart';
import '../../../../core/widgets/glass_segmented.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../core/widgets/group_cover_art.dart';
import '../../../../core/widgets/person_avatar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../data/models/group.dart';
import '../../../../data/models/person.dart';
import '../../../../data/repositories/in_memory_app_repository.dart';

class CreateEditGroupSheet extends ConsumerStatefulWidget {
  final Group? initialGroup;
  final String? prefillName;
  final GroupType? prefillType;
  final int? prefillCoverThemeIndex;
  final String? prefillSplitMode;

  const CreateEditGroupSheet({
    super.key,
    this.initialGroup,
    this.prefillName,
    this.prefillType,
    this.prefillCoverThemeIndex,
    this.prefillSplitMode,
  });

  static Future<void> show(
    BuildContext context, {
    Group? initialGroup,
    String? prefillName,
    GroupType? prefillType,
    int? prefillCoverThemeIndex,
    String? prefillSplitMode,
  }) {
    return AdaptivePresenter.show<void>(
      context: context,
      title: initialGroup != null ? 'Edit group' : 'New group',
      type: PresentationType.formOrConfirmation,
      child: CreateEditGroupSheet(
        initialGroup: initialGroup,
        prefillName: prefillName,
        prefillType: prefillType,
        prefillCoverThemeIndex: prefillCoverThemeIndex,
        prefillSplitMode: prefillSplitMode,
      ),
    );
  }

  @override
  ConsumerState<CreateEditGroupSheet> createState() => _CreateEditGroupSheetState();
}

class _CreateEditGroupSheetState extends ConsumerState<CreateEditGroupSheet> {
  late TextEditingController _nameController;
  late TextEditingController _memberNameController;
  late TextEditingController _memberPhoneController;
  late TextEditingController _memberUpiController;

  late GroupType _selectedType;
  late int _selectedCoverThemeIndex;
  late String _defaultSplitMode;
  late List<String> _memberIds;
  final List<Person> _newlyCreatedPeople = [];

  bool _isAddingMember = false;
  String? _nameError;
  String? _memberError;

  @override
  void initState() {
    super.initState();
    final g = widget.initialGroup;
    _nameController = TextEditingController(text: g?.name ?? widget.prefillName ?? '');
    _memberNameController = TextEditingController();
    _memberPhoneController = TextEditingController();
    _memberUpiController = TextEditingController();

    _selectedType = g?.type ?? widget.prefillType ?? GroupType.trip;
    _selectedCoverThemeIndex = g?.coverThemeIndex ?? widget.prefillCoverThemeIndex ?? 0;
    _defaultSplitMode = g?.defaultSplitMode ?? widget.prefillSplitMode ?? 'equal';

    if (g != null) {
      _memberIds = List.from(g.memberIds);
    } else {
      final repo = ref.read(appRepositoryProvider);
      _memberIds = [repo.currentUserId];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _memberNameController.dispose();
    _memberPhoneController.dispose();
    _memberUpiController.dispose();
    super.dispose();
  }

  void _onAddMember() {
    final rawName = _memberNameController.text.trim();
    if (rawName.isEmpty) {
      setState(() => _memberError = 'Name is required');
      return;
    }
    final upiTrimmed = _memberUpiController.text.trim();
    if (upiTrimmed.isNotEmpty &&
        !RegExp(r'^[\w.\-]+@[\w\-]+$').hasMatch(upiTrimmed)) {
      setState(() => _memberError = 'Invalid UPI ID format (e.g. name@bank)');
      return;
    }
    final normalized = NameNormalizer.normalize(rawName);

    // Check duplicate in current group
    final repo = ref.read(appRepositoryProvider);
    final allPeople = repo.getPeople();
    final existingMember = _memberIds.any((id) {
      final p = repo.getPerson(id) ?? _newlyCreatedPeople.where((np) => np.id == id).firstOrNull;
      return p?.name.trim().toLowerCase() == normalized.toLowerCase();
    });

    if (existingMember) {
      setState(() => _memberError = '$normalized is already in this group');
      return;
    }

    // Check if person exists in repo
    Person? existingPerson = allPeople.where((p) => p.name.trim().toLowerCase() == normalized.toLowerCase()).firstOrNull;

    if (existingPerson != null) {
      setState(() {
        _memberIds.add(existingPerson.id);
        _memberNameController.clear();
        _memberPhoneController.clear();
        _memberUpiController.clear();
        _isAddingMember = false;
        _memberError = null;
      });
    } else {
      final phone = _memberPhoneController.text.trim().isEmpty ? null : _memberPhoneController.text.trim();
      final upi = _memberUpiController.text.trim().isEmpty ? null : _memberUpiController.text.trim();
      final newPerson = Person(
        id: 'usr_${DateTime.now().millisecondsSinceEpoch}_${_memberIds.length}',
        name: normalized,
        phone: phone,
        upiId: upi,
      );
      setState(() {
        _newlyCreatedPeople.add(newPerson);
        _memberIds.add(newPerson.id);
        _memberNameController.clear();
        _memberPhoneController.clear();
        _memberUpiController.clear();
        _isAddingMember = false;
        _memberError = null;
      });
    }
  }

  void _onSave() {
    final rawName = _nameController.text.trim();
    if (rawName.isEmpty) {
      setState(() => _nameError = 'Group name cannot be empty');
      return;
    }
    final normalizedName = NameNormalizer.normalize(rawName);

    final repo = ref.read(appRepositoryProvider);
    final allGroups = repo.getGroups();

    // Check uniqueness (except current group if editing)
    final duplicate = allGroups.any((g) =>
        g.id != widget.initialGroup?.id &&
        !g.isPersonal &&
        g.name.trim().toLowerCase() == normalizedName.toLowerCase());

    if (duplicate) {
      setState(() => _nameError = 'A group named "$normalizedName" already exists');
      return;
    }

    if (_memberIds.length < 2) {
      setState(() => _memberError = 'A group must have at least 2 members');
      return;
    }

    final outcome = GuestWriteGuard.checkAndRecord(context, ref);
    if (outcome == GuestLimitOutcome.hardBlocked) return;

    final repoNotifier = ref.read(appStateProvider.notifier);

    // Add newly created people to repo
    for (final p in _newlyCreatedPeople) {
      repoNotifier.addPerson(p);
    }

    if (widget.initialGroup != null) {
      final updated = widget.initialGroup!.copyWith(
        name: normalizedName,
        type: _selectedType,
        coverThemeIndex: _selectedCoverThemeIndex,
        defaultSplitMode: _defaultSplitMode,
        memberIds: _memberIds,
      );
      repoNotifier.updateGroup(updated);
    } else {
      final newGroup = Group(
        id: 'grp_${DateTime.now().millisecondsSinceEpoch}',
        name: normalizedName,
        type: _selectedType,
        coverThemeIndex: _selectedCoverThemeIndex,
        defaultSplitMode: _defaultSplitMode,
        memberIds: _memberIds,
        createdAt: DateTime.now(),
      );
      repoNotifier.addGroup(newGroup);
    }

    Navigator.of(context, rootNavigator: true).pop();
    GuestWriteGuard.showPromptIfNeeded(context, outcome);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final repo = ref.watch(appRepositoryProvider);
    final currentUserId = repo.currentUserId;

    // Build temporary group for live cover preview
    final previewGroup = Group(
      id: widget.initialGroup?.id ?? 'preview',
      name: _nameController.text.isEmpty ? 'Preview' : _nameController.text,
      type: _selectedType,
      coverThemeIndex: _selectedCoverThemeIndex,
      memberIds: _memberIds,
    );

    return FormSheetScaffold(
      bottomBar: PrimaryButton(
        label: widget.initialGroup != null ? 'Save changes' : 'Create group',
        onPressed: _onSave,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Live Cover Swatch Preview
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 100,
              child: GroupCoverArt(
                group: previewGroup,
                height: 100,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Group Name
          Text('GROUP NAME', style: AppTypography.sectionLabel.copyWith(color: theme.secondary, letterSpacing: 0.8, fontSize: 11)),
          const SizedBox(height: 6),
          GlassSurface(
            level: GlassLevel.level1,
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              style: AppTypography.bodyMedium.copyWith(color: theme.ink),
              decoration: InputDecoration(
                hintText: 'e.g. Goa Trip, Flatmates, Ladakh 2026',
                hintStyle: AppTypography.body.copyWith(color: theme.tertiary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
          ),
          if (_nameError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(_nameError!, style: TextStyle(fontFamily: AppTypography.fontBody, fontSize: 11, color: theme.textCoral, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 16),

          // Group Type Selector
          Text('TYPE', style: AppTypography.sectionLabel.copyWith(color: theme.secondary, letterSpacing: 0.8, fontSize: 11)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: GroupType.values.map((type) {
              final isSel = _selectedType == type;
              return ChoiceChip(
                label: Text(type.label),
                selected: isSel,
                onSelected: (val) {
                  if (val) setState(() => _selectedType = type);
                },
                selectedColor: theme.accent.withValues(alpha: 0.2),
                backgroundColor: theme.surface.withValues(alpha: 0.4),
                labelStyle: TextStyle(
                  fontFamily: AppTypography.fontBody,
                  fontSize: 12,
                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  color: isSel ? theme.accent : theme.ink,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isSel ? theme.accent : theme.hairline),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // 6 Cover Swatches
          Text('COVER THEME', style: AppTypography.sectionLabel.copyWith(color: theme.secondary, letterSpacing: 0.8, fontSize: 11)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (idx) {
              final isSel = _selectedCoverThemeIndex == idx;
              final palette = theme.coverThemePalettes[idx];
              return GestureDetector(
                onTap: () => setState(() => _selectedCoverThemeIndex = idx),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: palette, begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSel ? theme.accent : theme.hairline,
                      width: isSel ? 2.5 : 1.0,
                    ),
                    boxShadow: isSel
                        ? [BoxShadow(color: palette.first.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))]
                        : null,
                  ),
                  child: isSel ? Icon(Icons.check_rounded, color: theme.white, size: 20) : null,
                ),
              );
            }),
          ),
          const SizedBox(height: 18),

          // Default Split Mode
          Text('DEFAULT SPLIT', style: AppTypography.sectionLabel.copyWith(color: theme.secondary, letterSpacing: 0.8, fontSize: 11)),
          const SizedBox(height: 6),
          GlassSegmented<String>(
            values: const ['equal', 'exact', 'percent'],
            labels: const ['Equal', 'Exact', 'Percent'],
            selectedValue: _defaultSplitMode,
            onValueChanged: (val) => setState(() => _defaultSplitMode = val),
          ),
          const SizedBox(height: 18),

          // Members Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('MEMBERS (${_memberIds.length})', style: AppTypography.sectionLabel.copyWith(color: theme.secondary, letterSpacing: 0.8, fontSize: 11)),
              if (!_isAddingMember)
                InkWell(
                  onTap: () => setState(() => _isAddingMember = true),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text('+ Add member', style: TextStyle(fontFamily: AppTypography.fontBody, fontSize: 12, fontWeight: FontWeight.w700, color: theme.accent)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Members list chips / rows
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _memberIds.map((id) {
              final p = repo.getPerson(id) ?? _newlyCreatedPeople.where((np) => np.id == id).firstOrNull;
              final isCurrentUser = id == currentUserId;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: theme.hairline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PersonAvatar(person: p, size: 22),
                    const SizedBox(width: 6),
                    Text(
                      isCurrentUser ? '${p?.name ?? "You"} (You)' : (p?.name ?? 'Member'),
                      style: AppTypography.caption.copyWith(color: theme.ink, fontWeight: FontWeight.w600),
                    ),
                    if (!isCurrentUser) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _memberIds.remove(id);
                            _newlyCreatedPeople.removeWhere((np) => np.id == id);
                          });
                        },
                        child: Icon(Icons.close_rounded, size: 14, color: theme.muted),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),

          if (_memberError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(_memberError!, style: TextStyle(fontFamily: AppTypography.fontBody, fontSize: 11, color: theme.textCoral, fontWeight: FontWeight.w600)),
            ),

          // Inline Add Member Form
          if (_isAddingMember) ...[
            const SizedBox(height: 12),
            GlassSurface(
              level: GlassLevel.level1,
              borderRadius: 16,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _memberNameController,
                    textCapitalization: TextCapitalization.words,
                    style: AppTypography.bodyMedium.copyWith(color: theme.ink),
                    decoration: InputDecoration(
                      hintText: 'Member name (Required)',
                      hintStyle: AppTypography.body.copyWith(color: theme.tertiary, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                  Divider(height: 12, color: theme.hairline),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _memberPhoneController,
                          keyboardType: TextInputType.phone,
                          style: AppTypography.bodyMedium.copyWith(color: theme.ink, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Phone (optional)',
                            hintStyle: AppTypography.body.copyWith(color: theme.tertiary, fontSize: 12),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _memberUpiController,
                          style: AppTypography.bodyMedium.copyWith(color: theme.ink, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'UPI ID (optional)',
                            hintStyle: AppTypography.body.copyWith(color: theme.tertiary, fontSize: 12),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _isAddingMember = false),
                        child: Text('Cancel', style: TextStyle(color: theme.muted, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.accent,
                          foregroundColor: theme.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _onAddMember,
                        child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
