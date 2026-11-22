import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'device_profile.dart';

DeviceProfile detectDevice() {
  try {
    // 1. Debug-only override: ?device=desktop|touch (honored ONLY in debug/test, never in release)
    if (kDebugMode) {
      final search = web.window.location.search;
      final uri = Uri.tryParse(search);
      final override = uri?.queryParameters['device']?.toLowerCase();
      if (override == 'desktop') {
        return const DeviceProfile(deviceClass: DeviceClass.desktop);
      } else if (override == 'touch') {
        return const DeviceProfile(deviceClass: DeviceClass.touch);
      }
    }

    final nav = web.window.navigator;
    final ua = nav.userAgent.toLowerCase();

    // 2. Touch detection: matchMedia pointer:coarse and hover:none
    final hasPointerCoarse = web.window.matchMedia('(pointer: coarse)').matches;
    final hasHoverNone = web.window.matchMedia('(hover: none)').matches;
    final mediaQueryTouch = hasPointerCoarse && hasHoverNone;

    // 3. Mobile / tablet user agent
    final uaTouch = ua.contains('iphone') ||
        ua.contains('ipod') ||
        ua.contains('ipad') ||
        ua.contains('android') ||
        ua.contains('mobile') ||
        ua.contains('tablet');

    // 4. iPadOS detection: Macintosh with maxTouchPoints > 1
    final isIpadOs = ua.contains('macintosh') && nav.maxTouchPoints > 1;

    final isTouch = mediaQueryTouch || uaTouch || isIpadOs;

    final hardwareConcurrency = nav.hardwareConcurrency;
    // deviceMemory is an experimental web API
    double? mem;
    try {
      final jsNav = nav as dynamic;
      mem = (jsNav.deviceMemory as num?)?.toDouble();
    } catch (_) {
      mem = null;
    }

    return DeviceProfile(
      deviceClass: isTouch ? DeviceClass.touch : DeviceClass.desktop,
      hardwareConcurrency: hardwareConcurrency,
      deviceMemory: mem,
    );
  } catch (_) {
    return const DeviceProfile(deviceClass: DeviceClass.desktop);
  }
}
