import 'device_auth.dart';

DeviceAuth createDeviceAuth() => StubDeviceAuth();

class StubDeviceAuth implements DeviceAuth {
  @override
  Future<bool> isPlatformAuthenticatorAvailable() async => false;

  @override
  Future<String?> registerCredential({
    required String challenge,
    required String rpId,
    required String userId,
    required String userName,
  }) async => null;

  @override
  Future<bool> verifyCredential({
    required String credentialId,
    required String challenge,
    required String rpId,
  }) async => false;
}
