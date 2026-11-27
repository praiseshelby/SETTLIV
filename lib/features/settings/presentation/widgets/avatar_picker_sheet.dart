import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/auth/auth_repository.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/adaptive_presenter.dart';
import '../../../../core/widgets/form_sheet_scaffold.dart';
import '../../../../core/widgets/person_avatar.dart';
import '../../../../core/widgets/stock_avatar_painter.dart';
import '../../../../data/repositories/in_memory_app_repository.dart';

class AvatarPickerSheet extends ConsumerStatefulWidget {
  final Future<Uint8List?> Function()? pickImageBytesOverride;

  const AvatarPickerSheet({
    super.key,
    this.pickImageBytesOverride,
  });

  static Future<void> show(BuildContext context) {
    return AdaptivePresenter.show<void>(
      context: context,
      title: 'Choose avatar',
      type: PresentationType.formOrConfirmation,
      child: const AvatarPickerSheet(),
    );
  }

  @override
  ConsumerState<AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends ConsumerState<AvatarPickerSheet> {
  static const int _maxUploadBytes = 200 * 1024;
  bool _isBusy = false;
  String? _error;

  Future<void> _selectStock(int index) async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final refStr = index.toString();
      final authRepo = ref.read(authRepositoryProvider);
      if (authRepo != null && ref.read(authStateProvider) is AuthSignedIn) {
        await authRepo.updateAvatar(avatarKind: 'stock', avatarRef: refStr);
      }
      final current = ref.read(currentUserProvider);
      if (current != null) {
        ref.read(appStateProvider.notifier).repository.updatePerson(
              current.copyWith(avatarKind: 'stock', avatarRef: refStr),
            );
        ref.read(appStateProvider.notifier).notifyChange();
      }
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Avatar stock update error: $e\n$st');
      }
      if (mounted) {
        setState(() => _error = 'Could not update avatar. Try again.');
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _removePhoto() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final authRepo = ref.read(authRepositoryProvider);
      if (authRepo != null && ref.read(authStateProvider) is AuthSignedIn) {
        await authRepo.updateAvatar(avatarKind: 'initials', avatarRef: null);
      }
      final current = ref.read(currentUserProvider);
      if (current != null) {
        ref.read(appStateProvider.notifier).repository.updatePerson(
              current.copyWith(avatarKind: 'initials', clearAvatarRef: true),
            );
        ref.read(appStateProvider.notifier).notifyChange();
      }
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Avatar remove error: $e\n$st');
      }
      if (mounted) {
        setState(() => _error = 'Could not remove avatar. Try again.');
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _uploadPhoto() async {
    if (_isBusy) return;
    final authRepo = ref.read(authRepositoryProvider);
    if (authRepo == null || ref.read(authStateProvider) is! AuthSignedIn) {
      setState(() => _error = 'Sign in to upload a custom photo.');
      return;
    }
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      Uint8List? bytes;
      if (widget.pickImageBytesOverride != null) {
        bytes = await widget.pickImageBytesOverride!();
      } else {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 256,
          maxHeight: 256,
          imageQuality: 85,
        );
        if (picked != null) {
          bytes = await picked.readAsBytes();
        }
      }
      if (bytes == null) return;
      if (bytes.length > _maxUploadBytes) {
        setState(() => _error = 'Image must be under 200 KB.');
        return;
      }
      final url = await authRepo.uploadAvatarBytes(bytes);
      await authRepo.updateAvatar(avatarKind: 'upload', avatarRef: url);
      final current = ref.read(currentUserProvider);
      if (current != null) {
        ref.read(appStateProvider.notifier).repository.updatePerson(
              current.copyWith(avatarKind: 'upload', avatarRef: url),
            );
        ref.read(appStateProvider.notifier).notifyChange();
      }
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Avatar upload error: $e\n$st');
      }
      if (mounted) {
        setState(() => _error = 'Could not upload photo. Keeping current avatar.');
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final current = ref.watch(currentUserProvider);
    final isSignedIn = ref.watch(authStateProvider) is AuthSignedIn;

    return FormSheetScaffold(
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isSignedIn) ...[
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryButtonBg,
                  foregroundColor: theme.primaryButtonText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: _isBusy ? null : _uploadPhoto,
                icon: _isBusy
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.primaryButtonText,
                        ),
                      )
                    : const Icon(Icons.upload_rounded, size: 18),
                label: const Text(
                  'Upload photo',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ] else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Stock avatars are available offline and in guest mode.',
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(color: theme.muted),
              ),
            ),
          SizedBox(
            height: 48,
            child: TextButton(
              onPressed: _isBusy ? null : _removePhoto,
              child: Text(
                'Remove photo',
                style: AppTypography.bodySemiBold.copyWith(color: theme.muted),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (current != null)
            Center(
              child: PersonAvatar(person: current, size: 64, showRing: true),
            ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: theme.textCoral,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
          ],
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: StockAvatarPainter.count,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemBuilder: (ctx, i) {
              final isSelected = current?.avatarKind == 'stock' &&
                  current?.avatarRef == i.toString();
              return InkWell(
                onTap: _isBusy ? null : () => _selectStock(i),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? theme.accent : theme.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: ClipOval(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: StockAvatarPainter(index: i, theme: theme),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
