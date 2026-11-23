import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../widgets/settliv_wordmark.dart';
import 'screen_lock_provider.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _hasAutoPrompted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasAutoPrompted && mounted) {
        _hasAutoPrompted = true;
        ref.read(screenLockProvider.notifier).unlock();
      }
    });
  }

  void _showEraseConfirmDialog(BuildContext context) {
    final theme = context.settliv;
    final controller = TextEditingController();
    bool canConfirm = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: theme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.hairline),
          ),
          title: Text(
            'Turn off lock and erase data?',
            style: TextStyle(
              color: theme.ink,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'If your browser security credentials have changed or become invalid, you can reset the app. This permanently erases all local data and disables the screen lock.',
                style: TextStyle(color: theme.muted, fontSize: 13.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Type DELETE to confirm:',
                style: TextStyle(color: theme.ink, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                onChanged: (val) {
                  setDialogState(() {
                    canConfirm = val.trim() == 'DELETE';
                  });
                },
                decoration: InputDecoration(
                  hintText: 'DELETE',
                  hintStyle: TextStyle(color: theme.muted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.hairline),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text('Cancel', style: TextStyle(color: theme.muted)),
            ),
            ElevatedButton(
              onPressed: canConfirm
                  ? () async {
                      Navigator.of(dialogCtx).pop();
                      await ref.read(screenLockProvider.notifier).turnOffLockAndEraseAllData();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.coral,
                foregroundColor: theme.surface,
              ),
              child: const Text('Erase all data'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final lockState = ref.watch(screenLockProvider);

    return Scaffold(
      backgroundColor: theme.canvas,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SettlivWordmark(fontSize: 32),
                const SizedBox(height: 12),
                Text(
                  'Locked with device security',
                  style: TextStyle(
                    color: theme.muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 48),
                if (lockState.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: theme.textCoral.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.textCoral.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      lockState.errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.textCoral, fontSize: 13),
                    ),
                  ),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: lockState.isAuthenticating
                        ? null
                        : () => ref.read(screenLockProvider.notifier).unlock(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryButtonBg,
                      foregroundColor: theme.primaryButtonText,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: lockState.isAuthenticating
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.primaryButtonText,
                            ),
                          )
                        : const Text(
                            'Unlock with device lock',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => _showEraseConfirmDialog(context),
                  child: Text(
                    'Lost access? Turn off lock & erase all data',
                    style: TextStyle(
                      color: theme.muted,
                      fontSize: 12.5,
                      decoration: TextDecoration.underline,
                    ),
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
