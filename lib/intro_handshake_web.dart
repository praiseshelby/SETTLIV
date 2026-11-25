import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

bool get isIntroRevealSupported => true;

/// Waits for `settliv-intro-reveal` on `window`, with a 1.8s fallback timer.
void listenForIntroReveal(VoidCallback onReveal) {
  var fired = false;
  Timer? fallback;

  void trigger() {
    if (fired) return;
    fired = true;
    fallback?.cancel();
    onReveal();
  }

  // If the intro already finished or was skipped before Flutter booted:
  if (web.document.getElementById('loading-screen') == null) {
    trigger();
    return;
  }

  late final JSFunction listener;
  listener = ((web.Event _) {
    web.window.removeEventListener('settliv-intro-reveal', listener);
    trigger();
  }).toJS;

  web.window.addEventListener('settliv-intro-reveal', listener);
  fallback = Timer(const Duration(milliseconds: 1800), () {
    web.window.removeEventListener('settliv-intro-reveal', listener);
    trigger();
  });
}
