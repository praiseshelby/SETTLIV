import 'device_detector_stub.dart'
    if (dart.library.js_interop) 'device_detector_web.dart';

enum DeviceClass {
  desktop,
  touch,
}

class DeviceProfile {
  final DeviceClass deviceClass;
  final int? hardwareConcurrency;
  final double? deviceMemory;

  const DeviceProfile({
    required this.deviceClass,
    this.hardwareConcurrency,
    this.deviceMemory,
  });

  bool get isTouch => deviceClass == DeviceClass.touch;
  bool get isDesktop => deviceClass == DeviceClass.desktop;

  static DeviceProfile detect() => detectDevice();
}
