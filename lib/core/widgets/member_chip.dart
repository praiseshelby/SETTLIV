import 'package:flutter/material.dart';
import '../../data/models/person.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'person_avatar.dart';

class MemberChip extends StatelessWidget {
  final Person person;
  final bool isSelected;
  final ValueChanged<bool>? onSelected;
  final String? subtitle;

  const MemberChip({
    super.key,
    required this.person,
    required this.isSelected,
    this.onSelected,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final isDark = context.isDarkMode;

    final Color bgColor;
    final Color textColor;
    final Color borderColor;

    if (isSelected) {
      bgColor = isDark ? const Color(0xFF263760) : AppColors.midnightNavy;
      textColor = Colors.white;
      borderColor = Colors.transparent;
    } else {
      bgColor = theme.raised;
      textColor = theme.ink;
      borderColor = theme.hairline;
    }

    return Semantics(
      button: true,
      selected: isSelected,
      label: person.name,
      child: InkWell(
        onTap: onSelected != null ? () => onSelected!(!isSelected) : null,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.only(left: 4, right: 14, top: 4, bottom: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PersonAvatar(
                person: person,
                size: 26,
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    style: AppTypography.chip.copyWith(
                      color: textColor,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    Text(
                      subtitle!,
                      style: AppTypography.caption.copyWith(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.8)
                            : theme.secondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
