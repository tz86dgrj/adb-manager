class AvdInfo {
  final String id;
  final String name;
  final bool isRunning;
  final String? runningDeviceId;

  const AvdInfo({
    required this.id,
    required this.name,
    this.isRunning = false,
    this.runningDeviceId,
  });

  AvdInfo copyWith({
    String? id,
    String? name,
    bool? isRunning,
    String? runningDeviceId,
  }) {
    return AvdInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      isRunning: isRunning ?? this.isRunning,
      runningDeviceId: runningDeviceId ?? this.runningDeviceId,
    );
  }

  @override
  String toString() => 'AvdInfo(id: $id, isRunning: $isRunning, deviceId: $runningDeviceId)';
}
