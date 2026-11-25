import 'package:flutter/foundation.dart';

/// Listens for the web `settliv-intro-reveal` window event (non-web stub).
void listenForIntroReveal(VoidCallback onReveal) {
  onReveal();
}

bool get isIntroRevealSupported => false;
