import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../profile/experience_mode.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'aurora_background.dart';
import 'glass_surface.dart';
import 'settliv_wordmark.dart';

class PhoneFrame extends ConsumerStatefulWidget {
  final Widget child;

  const PhoneFrame({super.key, required this.child});

  static const double targetWidth = 390.0;
  static const double targetHeight = 844.0;
  static const double bezelWidth = 8.0;
  static const double cornerRadius = 44.0;
  static const String prefHintDismissed = 'settliv_phone_frame_hint_dismissed';

  @override
  ConsumerState<PhoneFrame> createState() => _PhoneFrameState();
}

class _PhoneFrameState extends ConsumerState<PhoneFrame> {
  bool _hintDismissed = false;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs != null) {
      _hintDismissed = prefs.getBool(PhoneFrame.prefHintDismissed) ?? false;
    }
  }

  void _dismissHint() {
    setState(() => _hintDismissed = true);
    final prefs = ref.read(sharedPreferencesProvider);
    prefs?.setBool(PhoneFrame.prefHintDismissed, true);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final isWideViewport = screenWidth > 600;

    // Never shown on phones / narrow viewports (<= 600px)
    if (!isWideViewport) {
      return widget.child;
    }

    final theme = context.settliv;
    const double totalFrameHeight = PhoneFrame.targetHeight + (PhoneFrame.bezelWidth * 2);
    const double totalFrameWidth = PhoneFrame.targetWidth + (PhoneFrame.bezelWidth * 2);

    return Scaffold(
      backgroundColor: theme.canvas,
      body: AuroraBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              children: [
                // 1. SETTLIV text wordmark above
                const SizedBox(height: 4),
                const Center(
                  child: SettlivWordmark(fontSize: 16),
                ),
                const SizedBox(height: 10),

                // 2. Centred phone frame fitted to viewport height
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Container(
                        width: totalFrameWidth,
                        height: totalFrameHeight,
                        decoration: BoxDecoration(
                          color: theme.surface,
                          borderRadius: BorderRadius.circular(PhoneFrame.cornerRadius + PhoneFrame.bezelWidth),
                          border: Border.all(
                            color: theme.hairline,
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.shadow.withValues(alpha: theme.isDark ? 0.45 : 0.22),
                              blurRadius: 44,
                              offset: const Offset(0, 20),
                              spreadRadius: -4,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(PhoneFrame.bezelWidth),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(PhoneFrame.cornerRadius),
                          child: SizedBox(
                            width: PhoneFrame.targetWidth,
                            height: PhoneFrame.targetHeight,
                            child: MediaQuery(
                              data: media.copyWith(
                                size: const Size(PhoneFrame.targetWidth, PhoneFrame.targetHeight),
                                padding: const EdgeInsets.only(top: 44, bottom: 24),
                                viewInsets: EdgeInsets.zero,
                              ),
                              child: widget.child,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Hint below: "Mobile app layout · compatibility preview. Settings › Experience"
                if (!_hintDismissed) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: GlassSurface(
                      level: GlassLevel.level1,
                      borderRadius: 999,
                      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => context.push('/settings'),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Mobile app layout · compatibility preview. ',
                                    style: AppTypography.caption.copyWith(
                                      color: theme.muted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Settings › Experience',
                                    style: AppTypography.caption.copyWith(
                                      color: theme.accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: _dismissHint,
                              child: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: theme.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
