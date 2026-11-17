import 'package:flutter/material.dart';
import '../../data/models/person.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class PersonAvatar extends StatelessWidget {
  final Person? person;
  final String? name;
  final double size;
  final bool showRing;

  const PersonAvatar({
    super.key,
    this.person,
    this.name,
    this.size = 32,
    this.showRing = true,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = person?.name ?? name ?? 'User';
    final initials = _extractInitials(displayName);
    final gradient = _getGradientForName(displayName);
    final theme = context.settliv;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        border: showRing
            ? Border.all(
                color: theme.surface.withValues(alpha: 0.9),
                width: 2.0,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(size * 0.15),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              initials,
              style: TextStyle(
                fontFamily: 'Manrope',
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.44,
                letterSpacing: -0.2,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _extractInitials(String input) {
    final parts = input.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  List<Color> _getGradientForName(String input) {
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = input.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final index = hash.abs() % AppColors.avatarGradients.length;
    return AppColors.avatarGradients[index];
  }
}
