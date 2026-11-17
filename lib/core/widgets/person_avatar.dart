import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../../data/models/person.dart';

class PersonAvatar extends StatelessWidget {
  final Person? person;
  final String? initials;
  final int gradientIndex;
  final double size;
  final bool hasRing;
  final Color? ringColor;

  const PersonAvatar({
    super.key,
    this.person,
    this.initials,
    this.gradientIndex = 0,
    this.size = 36.0,
    this.hasRing = false,
    this.ringColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveInitials = initials ??
        person?.avatarInitials ??
        (person != null && person!.name.isNotEmpty
            ? person!.name.substring(0, 1).toUpperCase()
            : '?');

    final effectiveIndex = (person?.avatarPairIndex ?? gradientIndex) %
        AppColors.avatarGradients.length;
    final gradientColors = AppColors.avatarGradients[effectiveIndex];

    final surfaceColor = ringColor ?? context.settliv.surface;

    final avatarCircle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Center(
        child: Text(
          effectiveInitials,
          style: AppTypography.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.38,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );

    if (!hasRing) {
      return avatarCircle;
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: surfaceColor,
          width: 2.0,
        ),
      ),
      child: avatarCircle,
    );
  }
}
