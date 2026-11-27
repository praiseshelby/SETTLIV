import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/name_normalizer.dart';
import '../../../core/widgets/adaptive_presenter.dart';
import '../../../core/widgets/form_sheet_scaffold.dart';
import '../../../core/widgets/glass_segmented.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/iou_note.dart';
import '../../../data/repositories/in_memory_app_repository.dart';

class CreateEditIouSheet extends ConsumerStatefulWidget {
  final IouNote? initialNote;

  const CreateEditIouSheet({super.key, this.initialNote});

  static Future<void> show(BuildContext context, {IouNote? initialNote}) {
    return AdaptivePresenter.show<void>(
      context: context,
      title: initialNote != null ? 'Edit IOU' : 'Add IOU note',
      type: PresentationType.formOrConfirmation,
      child: CreateEditIouSheet(initialNote: initialNote),
    );
  }

  @override
  ConsumerState<CreateEditIouSheet> createState() => _CreateEditIouSheetState();
}

class _CreateEditIouSheetState extends ConsumerState<CreateEditIouSheet> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late IouDirection _direction;
  DateTime? _dueDate;
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    final note = widget.initialNote;
    _nameController = TextEditingController(text: note?.personName ?? '');
    _phoneController = TextEditingController(text: note?.phone ?? '');
    _amountController = TextEditingController(
      text: note != null ? (note.amountPaise / 100).toStringAsFixed(note.amountPaise % 100 == 0 ? 0 : 2) : '',
    );
    _noteController = TextEditingController(text: note?.note ?? '');
    _direction = note?.direction ?? IouDirection.owedToMe;
    _dueDate = note?.dueDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  void _onSave() {
    setState(() => _attempted = true);

    final rawName = _nameController.text.trim();
    if (rawName.isEmpty) return;
    final name = NameNormalizer.normalize(rawName);

    final paise = CurrencyFormatter.parseToPaise(_amountController.text);
    if (paise == null || paise <= 0) return;

    final noteText = _noteController.text.trim();
    final phone = _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim();

    final repoNotifier = ref.read(appStateProvider.notifier);

    if (widget.initialNote != null) {
      final updated = widget.initialNote!.copyWith(
        personName: name,
        phone: phone,
        direction: _direction,
        amountPaise: paise,
        note: noteText,
        dueDate: _dueDate,
      );
      repoNotifier.updateIouNote(updated);
    } else {
      final newNote = IouNote(
        id: 'iou_${DateTime.now().millisecondsSinceEpoch}',
        personName: name,
        phone: phone,
        direction: _direction,
        amountPaise: paise,
        note: noteText,
        date: DateTime.now(),
        dueDate: _dueDate,
      );
      repoNotifier.addIouNote(newNote);
    }

    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final nameEmpty = _nameController.text.trim().isEmpty;
    final paise = CurrencyFormatter.parseToPaise(_amountController.text);
    final amountInvalid = paise == null || paise <= 0;

    return FormSheetScaffold(
      bottomBar: PrimaryButton(
        label: widget.initialNote != null ? 'Save changes' : 'Add IOU',
        onPressed: _onSave,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Direction selector
          GlassSegmented<IouDirection>(
            values: const [IouDirection.owedToMe, IouDirection.iOwe],
            labels: const ['They owe me', 'I owe them'],
            selectedValue: _direction,
            onValueChanged: (dir) => setState(() => _direction = dir),
          ),
          const SizedBox(height: 16),

          // Person Name
          Text('PERSON', style: AppTypography.sectionLabel.copyWith(color: theme.secondary, letterSpacing: 0.8, fontSize: 11)),
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
                hintText: "Who is this note for?",
                hintStyle: AppTypography.body.copyWith(color: theme.tertiary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_attempted && nameEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text('Name is required', style: TextStyle(fontFamily: AppTypography.fontBody, fontSize: 11, color: theme.textCoral, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 14),

          // Amount
          Text('AMOUNT', style: AppTypography.sectionLabel.copyWith(color: theme.secondary, letterSpacing: 0.8, fontSize: 11)),
          const SizedBox(height: 6),
          GlassSurface(
            level: GlassLevel.level1,
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                Text('₹', style: TextStyle(fontFamily: AppTypography.fontDisplay, fontSize: 18, fontWeight: FontWeight.w700, color: theme.secondary)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                    style: TextStyle(fontFamily: AppTypography.fontDisplay, fontSize: 18, fontWeight: FontWeight.w700, color: theme.ink),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(fontFamily: AppTypography.fontDisplay, fontSize: 18, color: theme.tertiary),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
          if (_attempted && amountInvalid)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text('Enter a valid amount', style: TextStyle(fontFamily: AppTypography.fontBody, fontSize: 11, color: theme.textCoral, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 14),

          // Note / Reason
          Text('NOTE / REASON', style: AppTypography.sectionLabel.copyWith(color: theme.secondary, letterSpacing: 0.8, fontSize: 11)),
          const SizedBox(height: 6),
          GlassSurface(
            level: GlassLevel.level1,
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              controller: _noteController,
              style: AppTypography.bodyMedium.copyWith(color: theme.ink),
              decoration: InputDecoration(
                hintText: 'e.g. Concert ticket, concert loan, rent share',
                hintStyle: AppTypography.body.copyWith(color: theme.tertiary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 14),

          // Optional Phone & Due Date Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PHONE (OPTIONAL)', style: AppTypography.sectionLabel.copyWith(color: theme.secondary, letterSpacing: 0.8, fontSize: 11)),
                    const SizedBox(height: 6),
                    GlassSurface(
                      level: GlassLevel.level1,
                      borderRadius: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: AppTypography.bodyMedium.copyWith(color: theme.ink),
                        decoration: InputDecoration(
                          hintText: '+91 9876543210',
                          hintStyle: AppTypography.body.copyWith(color: theme.tertiary, fontSize: 12),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DUE DATE (OPTIONAL)', style: AppTypography.sectionLabel.copyWith(color: theme.secondary, letterSpacing: 0.8, fontSize: 11)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _pickDueDate,
                      borderRadius: BorderRadius.circular(16),
                      child: GlassSurface(
                        level: GlassLevel.level1,
                        borderRadius: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Icon(Icons.event_outlined, size: 16, color: theme.muted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _dueDate != null ? DateFormatter.formatRelative(_dueDate!) : 'Set date',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: _dueDate != null ? theme.ink : theme.tertiary,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_dueDate != null)
                              GestureDetector(
                                onTap: () => setState(() => _dueDate = null),
                                child: Icon(Icons.close_rounded, size: 14, color: theme.muted),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
