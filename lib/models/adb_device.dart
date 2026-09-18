class AdbDevice {
  final String id;
  final String state; // 'device', 'offline', 'unauthorized', 'bootloader'
  final String? model;
  final String? product;
  final String? device;
  final String? transportId;
  final bool isEmulator;

  const AdbDevice({
    required this.id,
    required this.state,
    this.model,
    this.product,
    this.device,
    this.transportId,
    required this.isEmulator,
  });

  bool get isReady => state == 'device';

  String get displayName {
    if (model != null && model!.isNotEmpty) {
      return model!.replaceAll('_', ' ');
    }
    if (isEmulator) {
      return 'Android Emulator ($id)';
    }
    return id;
  }

  @override
  String toString() => 'AdbDevice(id: $id, state: $state, model: $model, isEmulator: $isEmulator)';
}
