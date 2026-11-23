import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'device_auth_stub.dart'
    if (dart.library.js_interop) 'device_auth_web.dart' as impl;

enum LockTimeout {
  immediately('Immediately', Duration.zero),
  thirtySeconds('30 seconds', Duration(seconds: 30)),
  oneMinute('1 minute', Duration(minutes: 1)),
  fiveMinutes('5 minutes', Duration(minutes: 5));

  final String label;
  final Duration duration;
  const LockTimeout(this.label, this.duration);
}

abstract class DeviceAuth {
  Future<bool> isPlatformAuthenticatorAvailable();
  Future<String?> registerCredential({
    required String challenge,
    required String rpId,
    required String userId,
    required String userName,
  });
  Future<bool> verifyCredential({
    required String credentialId,
    required String challenge,
    required String rpId,
  });
}

final deviceAuthProvider = Provider<DeviceAuth>((ref) {
  return impl.createDeviceAuth();
});
