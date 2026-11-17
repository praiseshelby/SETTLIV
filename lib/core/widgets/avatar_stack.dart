import 'package:flutter/material.dart';
import '../../data/models/person.dart';
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
    this.avatarSize = 30,
    this.overlap = 10,
  });

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();

    final effectiveSize = size ?? avatarSize;
    final visiblePeople = people.take(maxVisible).toList();
    final remainingCount = people.length - visiblePeople.length;
    final totalItems = visiblePeople.length + (remainingCount > 0 ? 1 : 0);
    final totalWidth =
        effectiveSize + (totalItems - 1) * (effectiveSize - overlap);

    return SizedBox(
      width: totalWidth,
      height: effectiveSize,
      child: Stack(
        children: [
          for (int i = 0; i < visiblePeople.length; i++)
            Positioned(
              left: i * (effectiveSize - overlap),
              child: PersonAvatar(
                person: visiblePeople[i],
                size: effectiveSize,
                showRing: true,
              ),
            ),
          if (remainingCount > 0)
            Positioned(
              left: visiblePeople.length * (effectiveSize - overlap),
              child: Container(
                width: effectiveSize,
                height: effectiveSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6B7280),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 2.0,
                  ),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '+$remainingCount',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: effectiveSize * 0.4,
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
