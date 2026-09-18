class DeviceProfile {
  final String id;
  final String name;
  final String oem;

  const DeviceProfile({
    required this.id,
    required this.name,
    this.oem = 'Google',
  });

  static const List<DeviceProfile> defaults = [
    DeviceProfile(id: 'pixel_7_pro', name: 'Pixel 7 Pro (1440 x 3120, 560 dpi)', oem: 'Google'),
    DeviceProfile(id: 'pixel_7', name: 'Pixel 7 (1080 x 2400, 420 dpi)', oem: 'Google'),
    DeviceProfile(id: 'pixel_6_pro', name: 'Pixel 6 Pro (1440 x 3120, 560 dpi)', oem: 'Google'),
    DeviceProfile(id: 'pixel_6', name: 'Pixel 6 (1080 x 2400, 420 dpi)', oem: 'Google'),
    DeviceProfile(id: 'resizable', name: 'Resizable Foldable / Tablet (Dynamic)', oem: 'Generic'),
    DeviceProfile(id: 'medium_phone', name: 'Medium Phone (1080 x 2400, 420 dpi)', oem: 'Generic'),
    DeviceProfile(id: 'pixel_tablet', name: 'Pixel Tablet (2560 x 1600, 320 dpi)', oem: 'Google'),
    DeviceProfile(id: 'medium_tablet', name: 'Medium Tablet 10" (1920 x 1200)', oem: 'Generic'),
    DeviceProfile(id: 'small_phone', name: 'Small Phone (720 x 1280, 320 dpi)', oem: 'Generic'),
  ];
}

class SystemImageInfo {
  final String packagePath;
  final String displayName;
  final String apiLevel;
  final String abi;
  final String tag;

  const SystemImageInfo({
    required this.packagePath,
    required this.displayName,
    required this.apiLevel,
    required this.abi,
    required this.tag,
  });
}

class AvdCreationResult {
  final bool success;
  final String message;
  final String? avdName;

  const AvdCreationResult({
    required this.success,
    required this.message,
    this.avdName,
  });
}
