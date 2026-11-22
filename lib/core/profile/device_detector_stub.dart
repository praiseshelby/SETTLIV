import 'device_profile.dart';

DeviceProfile detectDevice() {
  // Non-web platforms (future Android build / test environment) always use App (touch)
  return const DeviceProfile(
    deviceClass: DeviceClass.touch,
    hardwareConcurrency: 8,
    deviceMemory: 8,
  );
}
