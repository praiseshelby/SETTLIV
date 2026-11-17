import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

enum PrimaryButtonVariant {
  navy,
  emeraldConfirm,
}

class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final PrimaryButtonVariant variant;
  final Widget? leading;
  final Widget? trailing;
  final bool isLoading;
  final double height;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = PrimaryButtonVariant.navy,
    this.leading,
    this.trailing,
    this.isLoading = false,
    this.height = 56.0,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    final isDark = context.isDarkMode;

    final Color bgColor;
    final Color textColor;
    final Color shadowColor;

    if (widget.variant == PrimaryButtonVariant.emeraldConfirm) {
      bgColor = isDark ? AppColors.emeraldBright : AppColors.emerald;
      textColor = isDark ? const Color(0xFF042116) : Colors.white;
      shadowColor = AppColors.emerald.withValues(alpha: 0.3);
    } else {
      bgColor = isDark ? const Color(0xFF223460) : AppColors.midnightNavy;
      textColor = Colors.white;
      shadowColor = AppColors.midnightNavy.withValues(alpha: 0.25);
    }

    final double effectiveOpacity = isEnabled ? 1.0 : 0.45;

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Opacity(
            opacity: effectiveOpacity,
            child: Container(
              height: widget.height,
              width: double.infinity,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isEnabled
                    ? [
                        BoxShadow(
                          color: shadowColor,
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.0,
                ),
              ),
              child: Center(
                child: widget.isLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(textColor),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.leading != null) ...[
                            widget.leading!,
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              widget.label,
                              style: AppTypography.button.copyWith(
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (widget.trailing != null) ...[
                            const SizedBox(width: 8),
                            widget.trailing!,
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
