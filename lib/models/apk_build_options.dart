enum ApkBuildTarget {
  apk,
  appbundle,
}

enum ApkBuildMode {
  debug,
  profile,
  release,
}

class ApkBuildOptions {
  final ApkBuildTarget target;
  final ApkBuildMode mode;
  final bool splitPerAbi;
  final String? dartDefineFromFile;
  final String? flavor;
  final String? entrypoint;
  final String? additionalArgs;

  const ApkBuildOptions({
    this.target = ApkBuildTarget.apk,
    this.mode = ApkBuildMode.release,
    this.splitPerAbi = false,
    this.dartDefineFromFile,
    this.flavor,
    this.entrypoint,
    this.additionalArgs,
  });

  ApkBuildOptions copyWith({
    ApkBuildTarget? target,
    ApkBuildMode? mode,
    bool? splitPerAbi,
    String? dartDefineFromFile,
    String? flavor,
    String? entrypoint,
    String? additionalArgs,
  }) {
    return ApkBuildOptions(
      target: target ?? this.target,
      mode: mode ?? this.mode,
      splitPerAbi: splitPerAbi ?? this.splitPerAbi,
      dartDefineFromFile: dartDefineFromFile ?? this.dartDefineFromFile,
      flavor: flavor ?? this.flavor,
      entrypoint: entrypoint ?? this.entrypoint,
      additionalArgs: additionalArgs ?? this.additionalArgs,
    );
  }
}

class ApkBuildResult {
  final bool success;
  final String? primaryOutputFile;
  final List<String> allOutputFiles;
  final int? fileSizeBytes;
  final Duration duration;
  final String? errorMessage;
  final List<String> logs;

  const ApkBuildResult({
    required this.success,
    this.primaryOutputFile,
    this.allOutputFiles = const [],
    this.fileSizeBytes,
    this.duration = Duration.zero,
    this.errorMessage,
    this.logs = const [],
  });

  String get formattedFileSize {
    if (fileSizeBytes == null) return 'Unknown size';
    final mb = fileSizeBytes! / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB';
  }
}
