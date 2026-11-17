import 'package:flutter/material.dart';
import '../../data/models/person.dart';
import 'person_avatar.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class AvatarStack extends StatelessWidget {
  final List<Person> people;
  final double size;
  final double overlap;
  final int maxAvatars;

  const AvatarStack({
    super.key,
    required this.people,
    this.size = 28.0,
    this.overlap = 10.0,
    this.maxAvatars = 4,
  });

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();

    final visiblePeople = people.take(maxAvatars).toList();
    final remaining = people.length - visiblePeople.length;

    final totalWidth = visiblePeople.length * (size - overlap) +
        overlap +
        (remaining > 0 ? (size - overlap) : 0);

    return SizedBox(
      width: totalWidth,
      height: size + 4,
      child: Stack(
        children: [
          for (int i = 0; i < visiblePeople.length; i++)
            Positioned(
              left: i * (size - overlap),
              top: 2,
              child: PersonAvatar(
                person: visiblePeople[i],
                size: size,
                hasRing: true,
              ),
            ),
          if (remaining > 0)
            Positioned(
              left: visiblePeople.length * (size - overlap),
              top: 2,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.settliv.raised,
                  border: Border.all(
                    color: context.settliv.surface,
                    width: 2.0,
                  ),
                ),
                child: Center(
                  child: Text(
                    '+$remaining',
                    style: AppTypography.caption.copyWith(
                      fontSize: size * 0.36,
                      fontWeight: FontWeight.w700,
                      color: context.settliv.secondary,
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
