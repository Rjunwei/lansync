import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// 安全与身份管理服务
class SecurityService {
  static const _prefDeviceId = 'lansync_device_id';
  static const _prefFingerprint = 'lansync_fingerprint';
  static const _prefDeviceName = 'lansync_device_name';

  String deviceId = '';
  String fingerprint = 'INIT-0000';
  String deviceName = 'LanSync Device';

  /// 初始化本机身份信息
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 设备 ID
    String? id = prefs.getString(_prefDeviceId);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_prefDeviceId, id);
    }
    deviceId = id;

    // 安全指纹 (根据 ID + 随机盐生成一个固定的简短指纹)
    String? fp = prefs.getString(_prefFingerprint);
    if (fp == null || fp.isEmpty) {
      final digest = sha256.convert(utf8.encode('$deviceId-${DateTime.now().microsecondsSinceEpoch}'));
      // 提取前 8 位大写十六进制作为指纹: XXXX-XXXX
      final hex = digest.toString().toUpperCase();
      fp = '${hex.substring(0, 4)}-${hex.substring(4, 8)}';
      await prefs.setString(_prefFingerprint, fp);
    }
    fingerprint = fp;

    // 设备名称
    String? name = prefs.getString(_prefDeviceName);
    if (name == null || name.isEmpty) {
      name = _getDefaultDeviceName();
      await prefs.setString(_prefDeviceName, name);
    }
    deviceName = name;
  }

  /// 更新本机名称
  Future<void> updateDeviceName(String newName) async {
    if (newName.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    deviceName = newName.trim();
    await prefs.setString(_prefDeviceName, deviceName);
  }

  /// 获取系统默认名称
  String _getDefaultDeviceName() {
    if (Platform.isWindows) {
      return Platform.environment['COMPUTERNAME'] ?? 'Windows PC';
    } else if (Platform.isLinux) {
      return Platform.environment['HOSTNAME'] ?? 'Ubuntu Workstation';
    } else if (Platform.isAndroid) {
      return 'Android Phone';
    }
    return 'LanSync Device';
  }

  /// 生成 6 位随机核验安全 PIN 码
  String generatePairingPin() {
    final random = Random.secure();
    final pin = (100000 + random.nextInt(900000)).toString();
    return pin;
  }

  /// 生成临时配对 Token
  String generatePairingToken() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return base64UrlEncode(values);
  }

  /// 计算数据的 SHA-256
  static String calculateHash(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }
}
