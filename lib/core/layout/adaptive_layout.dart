import 'package:flutter/material.dart';

enum LayoutClass {
  compact,   // < 720
  medium,    // 720 - 1099
  expanded,  // >= 1100
}

class AdaptiveLayout {
  AdaptiveLayout._();

  static const double compactBreakpoint = 720.0;
  static const double expandedBreakpoint = 1100.0;
  static const double maxContentWidth = 1440.0;

  static LayoutClass of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return fromWidth(width);
  }

  static LayoutClass fromWidth(double width) {
    if (width < compactBreakpoint) {
      return LayoutClass.compact;
    } else if (width < expandedBreakpoint) {
      return LayoutClass.medium;
    } else {
      return LayoutClass.expanded;
    }
  }

  static bool isCompact(BuildContext context) => of(context) == LayoutClass.compact;
  static bool isMedium(BuildContext context) => of(context) == LayoutClass.medium;
  static bool isExpanded(BuildContext context) => of(context) == LayoutClass.expanded;
}
