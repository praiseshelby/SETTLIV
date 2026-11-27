import '../../../core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import '../../data/models/person.dart';
import '../theme/app_theme.dart';
import 'stock_avatar_painter.dart';

class PersonAvatar extends StatelessWidget {
  final Person? person;
  final String? name;
  final double size;
  final bool showRing;

  const PersonAvatar({
    super.key,
    this.person,
    this.name,
    this.size = 28,
    this.showRing = true,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = person?.name ?? name ?? 'User';
    final initials = _extractInitials(displayName);
    final theme = context.settliv;
    final gradient = _getGradientForName(displayName, theme);
    final kind = person?.avatarKind ?? 'initials';
    final refStr = person?.avatarRef;

    Widget inner;
    if (kind == 'stock' && refStr != null) {
      final idx = int.tryParse(refStr) ?? 0;
      inner = ClipOval(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.square(size),
            painter: StockAvatarPainter(index: idx, theme: theme),
          ),
        ),
      );
    } else if (kind == 'upload' && refStr != null && refStr.isNotEmpty) {
      inner = ClipOval(
        child: Image.network(
          refStr,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsChild(initials, theme),
        ),
      );
    } else {
      inner = _initialsChild(initials, theme);
    }

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
                color: theme.surface,
                width: 2.0,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: theme.shadow.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: inner,
    );
  }

  Widget _initialsChild(String initials, SettlivThemeExtension theme) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(size * 0.10),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            initials,
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              color: theme.white,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.44,
              letterSpacing: -0.2,
              height: 1.0,
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

  List<Color> _getGradientForName(String input, SettlivThemeExtension theme) {
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = input.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final index = hash.abs() % theme.avatarGradients.length;
    return theme.avatarGradients[index];
  }
}
