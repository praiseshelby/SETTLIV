import 'dart:math' as math;
import 'package:flutter/material.dart';

enum CoachPlacementSide { below, above, right, left, overlay }

@immutable
class CoachCardPlacement {
  final Rect cardRect;
  final CoachPlacementSide side;
  final double notchOffset;
  final Offset travelDirection;

  const CoachCardPlacement({
    required this.cardRect,
    required this.side,
    required this.notchOffset,
    required this.travelDirection,
  });
}

class CoachCardPlacementSolver {
  CoachCardPlacementSolver._();

  static const double defaultMargin = 16.0;
  static const double defaultGap = 14.0;
  static const double notchBaseHalfWidth = 9.0;

  static double preferredCardWidth({
    required double viewportWidth,
    required bool isExpandedWeb,
  }) {
    if (isExpandedWeb) {
      return 320.0.clamp(280.0, math.max(280.0, viewportWidth - 32.0));
    }
    return math.min(320.0, math.max(240.0, viewportWidth - 32.0));
  }

  static CoachCardPlacement compute({
    required Rect? targetRect,
    required Size viewportSize,
    required EdgeInsets safePadding,
    required Size cardSize,
    required bool isExpandedWeb,
    double bottomReserved = 0.0,
    double leftReserved = 0.0,
    double margin = defaultMargin,
    double gap = defaultGap,
  }) {
    final minX = safePadding.left + leftReserved + margin;
    final maxX = math.max(minX + 1.0, viewportSize.width - safePadding.right - margin);
    final minY = safePadding.top + margin;
    final maxY = math.max(
      minY + 1.0,
      viewportSize.height - safePadding.bottom - bottomReserved - margin,
    );

    final clampedW = math.min(cardSize.width, maxX - minX);
    final clampedH = math.min(cardSize.height, maxY - minY);

    if (targetRect == null) {
      final double left = isExpandedWeb
          ? minX
          : ((viewportSize.width - clampedW) / 2)
              .clamp(minX, math.max(minX, maxX - clampedW));
      final double top = math.max(minY, maxY - clampedH);
      return CoachCardPlacement(
        cardRect: Rect.fromLTWH(left, top, clampedW, clampedH),
        side: CoachPlacementSide.overlay,
        notchOffset: clampedW / 2,
        travelDirection: const Offset(0, 10),
      );
    }

    final preference = isExpandedWeb
        ? const [
            CoachPlacementSide.right,
            CoachPlacementSide.left,
            CoachPlacementSide.below,
            CoachPlacementSide.above,
          ]
        : const [
            CoachPlacementSide.below,
            CoachPlacementSide.above,
            CoachPlacementSide.right,
            CoachPlacementSide.left,
          ];

    Rect? candidateRect(CoachPlacementSide side) {
      switch (side) {
        case CoachPlacementSide.below:
          final top = targetRect.bottom + gap;
          if (top + clampedH > maxY) return null;
          final left = (targetRect.center.dx - clampedW / 2)
              .clamp(minX, math.max(minX, maxX - clampedW)).toDouble();
          return Rect.fromLTWH(left, top, clampedW, clampedH);
        case CoachPlacementSide.above:
          final top = targetRect.top - gap - clampedH;
          if (top < minY) return null;
                final left = (targetRect.center.dx - clampedW / 2)
          .clamp(minX, math.max(minX, maxX - clampedW)).toDouble();
          return Rect.fromLTWH(left, top, clampedW, clampedH);
        case CoachPlacementSide.right:
          final left = targetRect.right + gap;
          if (left + clampedW > maxX) return null;
                final top = (targetRect.center.dy - clampedH / 2)
          .clamp(minY, math.max(minY, maxY - clampedH)).toDouble();
          return Rect.fromLTWH(left, top, clampedW, clampedH);
        case CoachPlacementSide.left:
          final left = targetRect.left - gap - clampedW;
          if (left < minX) return null;
          final top = (targetRect.center.dy - clampedH / 2)
              .clamp(minY, math.max(minY, maxY - clampedH)).toDouble();
          return Rect.fromLTWH(left, top, clampedW, clampedH);
        case CoachPlacementSide.overlay:
          return null;
      }
    }

    for (final side in preference) {
      final rect = candidateRect(side);
      if (rect != null && !rect.overlaps(targetRect)) {
        return CoachCardPlacement(
          cardRect: rect,
          side: side,
          notchOffset: _computeNotchOffset(side, rect, targetRect),
          travelDirection: _travelForSide(side),
        );
      }
    }

    // Fallback when target is tall and no side fits cleanly without overlap:
    // place in the region with the most vertical room inside safe bounds.
    final roomBelow = maxY - targetRect.bottom;
    final roomAbove = targetRect.top - minY;
    final double fallbackTop = roomBelow >= roomAbove
        ? math.max(minY, maxY - clampedH)
        : minY;
    final double fallbackLeft = (targetRect.center.dx - clampedW / 2)
        .clamp(minX, math.max(minX, maxX - clampedW));
    final fallbackRect = Rect.fromLTWH(fallbackLeft, fallbackTop, clampedW, clampedH);
    return CoachCardPlacement(
      cardRect: fallbackRect,
      side: CoachPlacementSide.overlay,
      notchOffset: clampedW / 2,
      travelDirection: const Offset(0, 10),
    );
  }

  static double _computeNotchOffset(
    CoachPlacementSide side,
    Rect cardRect,
    Rect targetRect,
  ) {
    const pad = 22.0;
    if (side == CoachPlacementSide.below || side == CoachPlacementSide.above) {
      final maxOff = math.max(pad, cardRect.width - pad);
      return (targetRect.center.dx - cardRect.left).clamp(pad, maxOff);
    }
    final maxOff = math.max(pad, cardRect.height - pad);
    return (targetRect.center.dy - cardRect.top).clamp(pad, maxOff);
  }

  static Offset _travelForSide(CoachPlacementSide side) {
    switch (side) {
      case CoachPlacementSide.below:
        return const Offset(0, 10);
      case CoachPlacementSide.above:
        return const Offset(0, -10);
      case CoachPlacementSide.right:
        return const Offset(10, 0);
      case CoachPlacementSide.left:
        return const Offset(-10, 0);
      case CoachPlacementSide.overlay:
        return const Offset(0, 10);
    }
  }
}
