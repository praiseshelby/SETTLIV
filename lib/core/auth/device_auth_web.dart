import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'device_auth.dart';

DeviceAuth createDeviceAuth() => WebDeviceAuth();

class WebDeviceAuth implements DeviceAuth {
  @override
  Future<bool> isPlatformAuthenticatorAvailable() async {
    try {
      if (!web.window.isSecureContext) return false;
      final promise = web.PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
      final jsBool = await promise.toDart;
      return jsBool.toDart;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> registerCredential({
    required String challenge,
    required String rpId,
    required String userId,
    required String userName,
  }) async {
    try {
      if (!web.window.isSecureContext) return null;
      final challengeBytes = Uint8List.fromList(utf8.encode(challenge)).toJS;
      final userIdBytes = Uint8List.fromList(utf8.encode(userId)).toJS;

      final optionsMap = {
        'publicKey': {
          'challenge': challengeBytes,
          'rp': {'name': 'Settliv', 'id': rpId},
          'user': {
            'id': userIdBytes,
            'name': userName,
            'displayName': userName,
          },
          'pubKeyCredParams': [
            {'type': 'public-key', 'alg': -7},
            {'type': 'public-key', 'alg': -257},
          ],
          'authenticatorSelection': {
            'authenticatorAttachment': 'platform',
            'userVerification': 'required',
            'residentKey': 'discouraged',
          },
          'attestation': 'none',
        }
      };

      final jsOptions = optionsMap.jsify() as web.CredentialCreationOptions;
      final promise = web.window.navigator.credentials.create(jsOptions);
      final cred = await promise.toDart;
      if (cred != null) {
        final id = (cred as dynamic).id;
        if (id != null) {
          return id.toString();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> verifyCredential({
    required String credentialId,
    required String challenge,
    required String rpId,
  }) async {
    try {
      if (!web.window.isSecureContext) return false;
      final challengeBytes = Uint8List.fromList(utf8.encode(challenge)).toJS;
      final idBytes = Uint8List.fromList(base64Url.decode(base64Url.normalize(credentialId))).toJS;

      final optionsMap = {
        'publicKey': {
          'challenge': challengeBytes,
          'rpId': rpId,
          'userVerification': 'required',
          'allowCredentials': [
            {
              'type': 'public-key',
              'id': idBytes,
            }
          ],
        }
      };

      final jsOptions = optionsMap.jsify() as web.CredentialRequestOptions;
      final promise = web.window.navigator.credentials.get(jsOptions);
      final cred = await promise.toDart;
      return cred != null;
    } catch (_) {
      return false;
    }
  }
}
