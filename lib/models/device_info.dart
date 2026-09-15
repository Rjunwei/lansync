/// 设备平台类型
enum DevicePlatform {
  windows,
  linux,
  android,
  unknown,
}

/// 局域网设备信息实体
class DeviceInfo {
  final String id;
  final String name;
  final DevicePlatform platform;
  final String ip;
  final int port;
  final String fingerprint; // 设备公钥/安全指纹 (8位字符)
  final DateTime lastSeen;

  DeviceInfo({
    required this.id,
    required this.name,
    required this.platform,
    required this.ip,
    required this.port,
    required this.fingerprint,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'platform': platform.name,
        'ip': ip,
        'port': port,
        'fingerprint': fingerprint,
      };

  factory DeviceInfo.fromJson(Map<String, dynamic> json, {String? fallbackIp}) {
    DevicePlatform parsePlatform(String? p) {
      if (p == null) return DevicePlatform.unknown;
      switch (p.toLowerCase()) {
        case 'windows':
          return DevicePlatform.windows;
        case 'linux':
          return DevicePlatform.linux;
        case 'android':
          return DevicePlatform.android;
        default:
          return DevicePlatform.unknown;
      }
    }

    return DeviceInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Device',
      platform: parsePlatform(json['platform'] as String?),
      ip: (json['ip'] as String?) ?? fallbackIp ?? '127.0.0.1',
      port: (json['port'] as int?) ?? 53317,
      fingerprint: json['fingerprint'] as String? ?? '',
      lastSeen: DateTime.now(),
    );
  }

  DeviceInfo copyWith({
    String? id,
    String? name,
    DevicePlatform? platform,
    String? ip,
    int? port,
    String? fingerprint,
    DateTime? lastSeen,
  }) {
    return DeviceInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      fingerprint: fingerprint ?? this.fingerprint,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
