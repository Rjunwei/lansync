/// 设备信任等级
enum TrustLevel {
  trusted, // 永久信任，可自动接收
  ask, // 每次接收需弹窗确认
  blocked, // 黑名单阻断
}

/// 信任库中的授权记录
class TrustRecord {
  final String deviceId;
  final String deviceName;
  final String fingerprint;
  final TrustLevel level;
  final DateTime addedAt;
  final bool autoAccept;

  TrustRecord({
    required this.deviceId,
    required this.deviceName,
    required this.fingerprint,
    required this.level,
    required this.addedAt,
    this.autoAccept = true,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'fingerprint': fingerprint,
        'level': level.name,
        'addedAt': addedAt.toIso8601String(),
        'autoAccept': autoAccept,
      };

  factory TrustRecord.fromJson(Map<String, dynamic> json) {
    TrustLevel parseLevel(String? l) {
      switch (l) {
        case 'trusted':
          return TrustLevel.trusted;
        case 'ask':
          return TrustLevel.ask;
        case 'blocked':
          return TrustLevel.blocked;
        default:
          return TrustLevel.ask;
      }
    }

    return TrustRecord(
      deviceId: json['deviceId'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? 'Device',
      fingerprint: json['fingerprint'] as String? ?? '',
      level: parseLevel(json['level'] as String?),
      addedAt: json['addedAt'] != null
          ? DateTime.tryParse(json['addedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      autoAccept: json['autoAccept'] as bool? ?? true,
    );
  }

  TrustRecord copyWith({
    String? deviceId,
    String? deviceName,
    String? fingerprint,
    TrustLevel? level,
    DateTime? addedAt,
    bool? autoAccept,
  }) {
    return TrustRecord(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      fingerprint: fingerprint ?? this.fingerprint,
      level: level ?? this.level,
      addedAt: addedAt ?? this.addedAt,
      autoAccept: autoAccept ?? this.autoAccept,
    );
  }
}
