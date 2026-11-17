import 'package:flutter/material.dart';
import '../../data/models/group.dart';
import '../../data/models/person.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'avatar_stack.dart';
import 'balance_pill.dart';
import 'glass_surface.dart';
import 'group_cover_art.dart';

class GroupCard extends StatefulWidget {
  final Group group;
  final List<Person> members;
  final int userNetPaise;
  final VoidCallback onTap;

  const GroupCard({
    super.key,
    required this.group,
    required this.members,
    required this.userNetPaise,
    required this.onTap,
  });

  @override
  State<GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<GroupCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    final String metaText = widget.group.type == GroupType.home
        ? '${widget.members.length} people · Home'
        : '${widget.members.length} people · Trip';

    final double scale = _isPressed ? 0.98 : 1.0;
    final double translateY = (_isHovered && !_isPressed) ? -2.0 : 0.0;

    return Semantics(
      button: true,
      label: '${widget.group.name} group',
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            transform: Matrix4.identity()
              ..scale(scale)
              ..translate(0.0, translateY),
            child: GlassSurface(
              level: GlassLevel.level2,
              borderRadius: 28,
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'group-cover-${widget.group.id}',
                    child: GroupCoverArt(
                      group: widget.group,
                      height: 84,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                widget.group.name,
                                style: AppTypography.titleMedium.copyWith(
                                  color: theme.ink,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            BalancePill(
                              paise: widget.userNetPaise,
                              compact: false,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            AvatarStack(
                              people: widget.members,
                              avatarSize: 28,
                              overlap: 10,
                            ),
                            Text(
                              metaText,
                              style: AppTypography.caption.copyWith(
                                color: theme.secondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
