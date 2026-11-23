import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/device_auth.dart';
import '../../../../core/auth/screen_lock_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_surface.dart';

class SecuritySettingsSection extends ConsumerStatefulWidget {
  const SecuritySettingsSection({super.key});

  @override
  ConsumerState<SecuritySettingsSection> createState() => _SecuritySettingsSectionState();
}

class _SecuritySettingsSectionState extends ConsumerState<SecuritySettingsSection> {
  bool _isCheckingAvailability = true;
  bool _isAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    final auth = ref.read(deviceAuthProvider);
    final available = await auth.isPlatformAuthenticatorAvailable();
    if (mounted) {
      setState(() {
        _isAvailable = available;
        _isCheckingAvailability = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final lockState = ref.watch(screenLockProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PRIVACY & SECURITY',
          style: AppTypography.caption.copyWith(
            color: theme.muted,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        GlassSurface(
          level: GlassLevel.level1,
          borderRadius: 20,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Screen lock',
                          style: AppTypography.body.copyWith(
                            color: theme.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _isCheckingAvailability
                              ? 'Checking device capability...'
                              : !_isAvailable
                                  ? 'This device or browser doesn\'t offer a device lock for web apps'
                                  : 'Require fingerprint, face, or device PIN to open Settliv',
                          style: AppTypography.caption.copyWith(
                            color: theme.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isCheckingAvailability)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Switch.adaptive(
                      value: lockState.isEnabled,
                      onChanged: !_isAvailable || lockState.isAuthenticating
                          ? null
                          : (enable) async {
                              if (enable) {
                                await ref.read(screenLockProvider.notifier).enableLock();
                              } else {
                                await ref.read(screenLockProvider.notifier).disableLock();
                              }
                            },
                      activeColor: theme.accent,
                    ),
                ],
              ),
              if (lockState.isEnabled) ...[
                const SizedBox(height: 16),
                Divider(color: theme.hairline, height: 1),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lock timeout',
                      style: AppTypography.bodySemiBold.copyWith(
                        color: theme.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<LockTimeout>(
                        value: lockState.timeout,
                        dropdownColor: theme.surface,
                        style: AppTypography.bodySemiBold.copyWith(
                          color: theme.ink,
                          fontWeight: FontWeight.w600,
                        ),
                        items: LockTimeout.values.map((t) {
                          return DropdownMenuItem<LockTimeout>(
                            value: t,
                            child: Text(t.label),
                          );
                        }).toList(),
                        onChanged: (newTimeout) {
                          if (newTimeout != null) {
                            ref.read(screenLockProvider.notifier).setTimeout(newTimeout);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'Uses your device\'s own lock. It keeps casual viewers out of the app but does not encrypt data stored in this browser.',
                style: AppTypography.caption.copyWith(
                  color: theme.muted,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
