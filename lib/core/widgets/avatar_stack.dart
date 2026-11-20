import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/models/person.dart';
import '../theme/app_theme.dart';
import 'person_avatar.dart';

class AvatarStack extends StatelessWidget {
  final List<Person> people;
  final int maxVisible;
  final double? size;
  final double avatarSize;
  final double overlap;

  const AvatarStack({
    super.key,
    required this.people,
    this.maxVisible = 3,
    this.size,
    this.avatarSize = 28,
    this.overlap = 8,
  });

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();

    final theme = context.settliv;
    final effectiveSize = size ?? avatarSize;
    final visiblePeople = people.take(maxVisible).toList();
    final remainingCount = people.length - visiblePeople.length;
    final totalItems = visiblePeople.length + (remainingCount > 0 ? 1 : 0);

    // Measure initials with TextPainter to ensure overlap NEVER touches initials
    double maxInitialsWidth = 0.0;
    for (final person in visiblePeople) {
      final tp = TextPainter(
        text: TextSpan(
          text: person.avatarInitials,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
            fontSize: effectiveSize * 0.40,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      if (tp.width > maxInitialsWidth) {
        maxInitialsWidth = tp.width;
      }
    }

    // Safe overlap: right edge of initials is at (effectiveSize + maxInitialsWidth)/2.
    // The next avatar covers from (effectiveSize - safeOverlap) to effectiveSize.
    // To ensure initials never intersect the overlapped area:
    // effectiveSize - safeOverlap >= (effectiveSize + maxInitialsWidth)/2 + 2px margin
    final maxSafeOverlap = math.max(4.0, ((effectiveSize - maxInitialsWidth) / 2) - 2.0);
    final effectiveOverlap = math.min(overlap, maxSafeOverlap);

    final totalWidth = effectiveSize + (totalItems - 1) * (effectiveSize - effectiveOverlap);

    return SizedBox(
      width: totalWidth,
      height: effectiveSize,
      child: Stack(
        children: [
          for (int i = 0; i < visiblePeople.length; i++)
            Positioned(
              left: i * (effectiveSize - effectiveOverlap),
              child: PersonAvatar(
                person: visiblePeople[i],
                size: effectiveSize,
                showRing: true,
              ),
            ),
          if (remainingCount > 0)
            Positioned(
              left: visiblePeople.length * (effectiveSize - effectiveOverlap),
              child: Container(
                width: effectiveSize,
                height: effectiveSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.tertiary,
                  border: Border.all(
                    color: theme.surface,
                    width: 2.0,
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(effectiveSize * 0.10),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '+$remainingCount',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          color: theme.white,
                          fontWeight: FontWeight.w700,
                          fontSize: effectiveSize * 0.44,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
