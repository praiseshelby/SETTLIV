import 'package:flutter/material.dart';
import '../profile/device_profile.dart';

class MotionTokens {
  MotionTokens._();

  static const Duration durationFast = Duration(milliseconds: 120);
  static const Duration durationStandard = Duration(milliseconds: 240);
  static const Duration durationEmphasized = Duration(milliseconds: 360);
  static const Duration durationPageTransition = Duration(milliseconds: 280);
  static const Duration durationCrossFade = Duration(milliseconds: 300);

  static const Curve curveFast = Curves.easeOutCubic;
  static const Curve curveStandard = Curves.easeOutCubic;
  static const Curve curveEmphasized = Curves.easeOutQuart;

  static bool isLiteEffects(BuildContext context, [DeviceProfile? profile]) {
    final media = MediaQuery.maybeOf(context);
    if (media?.disableAnimations == true) return true;

    // Check hardware profile if available
    if (profile != null) {
      if (profile.hardwareConcurrency != null && profile.hardwareConcurrency! <= 4) {
        return true;
      }
      if (profile.deviceMemory != null && profile.deviceMemory! <= 4.0) {
        return true;
      }
    }
    return false;
  }
}
