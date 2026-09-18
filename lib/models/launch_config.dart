import 'dart:convert';

class LaunchConfig {
  final String? dartDefineFromFile;
  final String? target;
  final String? flavor;
  final String mode; // 'debug', 'profile', 'release'
  final String? additionalArgs;

  const LaunchConfig({
    this.dartDefineFromFile,
    this.target,
    this.flavor,
    this.mode = 'debug',
    this.additionalArgs,
  });

  LaunchConfig copyWith({
    String? dartDefineFromFile,
    String? target,
    String? flavor,
    String? mode,
    String? additionalArgs,
  }) {
    return LaunchConfig(
      dartDefineFromFile: dartDefineFromFile ?? this.dartDefineFromFile,
      target: target ?? this.target,
      flavor: flavor ?? this.flavor,
      mode: mode ?? this.mode,
      additionalArgs: additionalArgs ?? this.additionalArgs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dartDefineFromFile': dartDefineFromFile,
      'target': target,
      'flavor': flavor,
      'mode': mode,
      'additionalArgs': additionalArgs,
    };
  }

  factory LaunchConfig.fromMap(Map<String, dynamic> map) {
    return LaunchConfig(
      dartDefineFromFile: map['dartDefineFromFile'] as String?,
      target: map['target'] as String?,
      flavor: map['flavor'] as String?,
      mode: map['mode'] as String? ?? 'debug',
      additionalArgs: map['additionalArgs'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory LaunchConfig.fromJson(String source) =>
      LaunchConfig.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
