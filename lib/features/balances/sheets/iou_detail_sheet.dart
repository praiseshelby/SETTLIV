import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/adaptive_presenter.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/undo_snackbar.dart';
import '../../../data/models/iou_note.dart';
import '../../../data/models/person.dart';
import '../../../data/repositories/in_memory_app_repository.dart';
import 'create_edit_iou_sheet.dart';

class IouDetailSheet extends ConsumerStatefulWidget {
  final IouNote note;

  const IouDetailSheet({super.key, required this.note});

  static Future<void> show(BuildContext context, {required IouNote note}) {
    return AdaptivePresenter.show<void>(
      context: context,
      title: 'IOU details',
      type: PresentationType.detailView,
      child: IouDetailSheet(note: note),
    );
  }

  @override
  ConsumerState<IouDetailSheet> createState() => _IouDetailSheetState();
}

class _IouDetailSheetState extends ConsumerState<IouDetailSheet> {
  bool _isPartialMode = false;
  final TextEditingController _partialAmountController = TextEditingController();

  @override
  void dispose() {
    _partialAmountController.dispose();
    super.dispose();
  }

  void _recordPayment(int paise) {
    if (paise <= 0) return;
    final repoNotifier = ref.read(appStateProvider.notifier);
    repoNotifier.recordIouPayment(widget.note.id, paise);
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _openWhatsApp() async {
    final phone = widget.note.phone;
    if (phone == null || phone.isEmpty) return;

    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final amountStr = CurrencyFormatter.formatPaise(widget.note.remainingPaise);
    final msg = Uri.encodeComponent(
      'Hi ${widget.note.personName}, friendly reminder regarding the IOU for $amountStr (${widget.note.note}).',
    );
    final url = Uri.parse('https://wa.me/$cleanPhone?text=$msg');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: msg));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WhatsApp link copied to clipboard')),
          );
        }
      }
    } catch (_) {}
  }

  void _deleteNote() {
    final repoNotifier = ref.read(appStateProvider.notifier);
    final noteId = widget.note.id;
    final noteName = widget.note.personName;

    repoNotifier.deleteIouNote(noteId);
    Navigator.of(context, rootNavigator: true).pop();

    UndoSnackbar.show(
      context: context,
      message: 'IOU with $noteName deleted',
      onUndo: () {
        repoNotifier.restoreIouNote(noteId);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final now = DateTime.now();
    final isOwedToMe = widget.note.direction == IouDirection.owedToMe;
    final remainingPaise = widget.note.remainingPaise;
    final isSettled = widget.note.isSettled;
    final dueLabel = widget.note.dueLabel(now);
    final isOverdue = widget.note.isOverdue(now);

    final syntheticPerson = Person(
      id: 'iou_${widget.note.id}',
      name: widget.note.personName,
      phone: widget.note.phone,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card
          GlassSurface(
            level: GlassLevel.level2,
            borderRadius: 20,
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                PersonAvatar(person: syntheticPerson, size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.note.personName,
                              style: TextStyle(
                                fontFamily: AppTypography.fontBrand,
                                fontFamilyFallback: AppTypography.brandFallback,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: theme.ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'IOU note',
                              style: AppTypography.caption.copyWith(
                                color: theme.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isSettled
                            ? 'All settled up'
                            : (isOwedToMe ? 'Owes you' : 'You owe'),
                        style: AppTypography.caption.copyWith(
                          color: isSettled
                              ? theme.textEmerald
                              : (isOwedToMe ? theme.textEmerald : theme.textCoral),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Amounts Card
          GlassSurface(
            level: GlassLevel.level1,
            borderRadius: 18,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total note', style: AppTypography.caption.copyWith(color: theme.muted)),
                    Text(
                      CurrencyFormatter.formatPaise(widget.note.amountPaise),
                      style: TextStyle(
                        fontFamily: AppTypography.fontDisplay,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.ink,
                      ),
                    ),
                  ],
                ),
                if (widget.note.paidPaise > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Already paid', style: AppTypography.caption.copyWith(color: theme.muted)),
                      Text(
                        CurrencyFormatter.formatPaise(widget.note.paidPaise),
                        style: TextStyle(
                          fontFamily: AppTypography.fontDisplay,
                          fontSize: 14,
                          color: theme.textEmerald,
                        ),
                      ),
                    ],
                  ),
                ],
                Divider(height: 20, color: theme.hairline),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Remaining',
                      style: AppTypography.bodySemiBold.copyWith(color: theme.ink),
                    ),
                    Text(
                      CurrencyFormatter.formatPaise(remainingPaise),
                      style: TextStyle(
                        fontFamily: AppTypography.fontDisplay,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isSettled ? theme.textEmerald : (isOwedToMe ? theme.textEmerald : theme.textCoral),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Details Metadata
          GlassSurface(
            level: GlassLevel.level1,
            borderRadius: 18,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.note.note.isNotEmpty) ...[
                  Text('Note', style: AppTypography.caption.copyWith(color: theme.secondary, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(widget.note.note, style: AppTypography.body.copyWith(color: theme.ink)),
                  const SizedBox(height: 10),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Created', style: AppTypography.caption.copyWith(color: theme.secondary, fontSize: 11)),
                    Text(DateFormatter.formatRelative(widget.note.date), style: AppTypography.caption.copyWith(color: theme.ink)),
                  ],
                ),
                if (dueLabel != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Due date', style: AppTypography.caption.copyWith(color: theme.secondary, fontSize: 11)),
                      Text(
                        dueLabel,
                        style: AppTypography.caption.copyWith(
                          color: isOverdue ? theme.textCoral : theme.ink,
                          fontWeight: isOverdue ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                if (widget.note.phone != null && widget.note.phone!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Phone', style: AppTypography.caption.copyWith(color: theme.secondary, fontSize: 11)),
                      Text(widget.note.phone!, style: AppTypography.caption.copyWith(color: theme.ink)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Actions
          if (!isSettled) ...[
            if (!_isPartialMode) ...[
              PrimaryButton(
                label: isOwedToMe
                    ? 'Mark received (${CurrencyFormatter.formatPaise(remainingPaise)})'
                    : 'Mark paid (${CurrencyFormatter.formatPaise(remainingPaise)})',
                onPressed: () => _recordPayment(remainingPaise),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => setState(() => _isPartialMode = true),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Record partial payment',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTypography.fontBody,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.accent,
                    ),
                  ),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: GlassSurface(
                      level: GlassLevel.level1,
                      borderRadius: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Row(
                        children: [
                          Text('₹', style: TextStyle(fontFamily: AppTypography.fontDisplay, fontSize: 16, fontWeight: FontWeight.w700, color: theme.secondary)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _partialAmountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                              style: TextStyle(fontFamily: AppTypography.fontDisplay, fontSize: 16, fontWeight: FontWeight.w700, color: theme.ink),
                              decoration: const InputDecoration(
                                hintText: 'Partial amount',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PrimaryButton(
                    label: 'Save',
                    onPressed: () {
                      final p = CurrencyFormatter.parseToPaise(_partialAmountController.text);
                      if (p != null && p > 0) {
                        _recordPayment(p.clamp(1, remainingPaise));
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => setState(() => _isPartialMode = false),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('Cancel partial payment', textAlign: TextAlign.center, style: AppTypography.caption.copyWith(color: theme.muted)),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],

          // Nudge via WhatsApp if phone present and owed to user
          if (isOwedToMe && !isSettled && widget.note.phone != null && widget.note.phone!.isNotEmpty) ...[
            InkWell(
              onTap: _openWhatsApp,
              borderRadius: BorderRadius.circular(16),
              child: GlassSurface(
                level: GlassLevel.level1,
                borderRadius: 16,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, size: 18, color: theme.textEmerald),
                    const SizedBox(width: 8),
                    Text(
                      'Nudge via WhatsApp',
                      style: AppTypography.bodySemiBold.copyWith(color: theme.textEmerald, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Edit & Delete Buttons
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    CreateEditIouSheet.show(context, initialNote: widget.note);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: GlassSurface(
                    level: GlassLevel.level1,
                    borderRadius: 14,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_outlined, size: 16, color: theme.ink),
                        const SizedBox(width: 6),
                        Text('Edit note', style: AppTypography.caption.copyWith(color: theme.ink, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: _deleteNote,
                  borderRadius: BorderRadius.circular(14),
                  child: GlassSurface(
                    level: GlassLevel.level1,
                    borderRadius: 14,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 16, color: theme.textCoral),
                        const SizedBox(width: 6),
                        Text('Delete', style: AppTypography.caption.copyWith(color: theme.textCoral, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
