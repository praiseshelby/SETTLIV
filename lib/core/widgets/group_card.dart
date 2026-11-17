import 'package:flutter/material.dart';
import '../../data/models/group.dart';
import '../../data/models/person.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'group_cover_art.dart';
import 'avatar_stack.dart';
import 'balance_pill.dart';

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
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    return Semantics(
      button: true,
      label: '${widget.group.name} group',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.hairline,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: context.isDarkMode ? 0.2 : 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GroupCoverArt(
                  coverType: widget.group.coverType,
                  height: 108,
                  borderRadius: 0,
                  heroTag: 'group-cover-${widget.group.id}',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
                              style: AppTypography.sectionHeader.copyWith(
                                color: theme.ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          BalancePill(
                            paise: widget.userNetPaise,
                            compact: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AvatarStack(
                            people: widget.members,
                            size: 26,
                            overlap: 8,
                          ),
                          Text(
                            widget.group.type == GroupType.home
                                ? 'Home group'
                                : 'Trip',
                            style: AppTypography.caption.copyWith(
                              color: theme.secondary,
                              fontWeight: FontWeight.w500,
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
    );
  }
}
