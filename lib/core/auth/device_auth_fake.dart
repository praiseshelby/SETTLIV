import 'device_auth.dart';

class FakeDeviceAuth implements DeviceAuth {
  bool isAvailable;
  bool shouldSucceed;
  String? lastRegisteredCredentialId;

  FakeDeviceAuth({
    this.isAvailable = true,
    this.shouldSucceed = true,
  });

  @override
  Future<bool> isPlatformAuthenticatorAvailable() async => isAvailable;

  @override
  Future<String?> registerCredential({
    required String challenge,
    required String rpId,
    required String userId,
    required String userName,
  }) async {
    if (!isAvailable || !shouldSucceed) return null;
    final credId = 'cred_${DateTime.now().millisecondsSinceEpoch}';
    lastRegisteredCredentialId = credId;
    return credId;
  }

  @override
  Future<bool> verifyCredential({
    required String credentialId,
    required String challenge,
    required String rpId,
  }) async {
    if (!isAvailable) return false;
    return shouldSucceed;
  }
}
