import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trust_record.dart';

/// 设备白名单与信任管理服务
class TrustStoreService extends ChangeNotifier {
  static const _prefTrustListKey = 'lansync_trust_records';

  final Map<String, TrustRecord> _records = {};

  List<TrustRecord> get allRecords => _records.values.toList();
  List<TrustRecord> get trustedDevices =>
      _records.values.where((r) => r.level == TrustLevel.trusted).toList();
  List<TrustRecord> get blockedDevices =>
      _records.values.where((r) => r.level == TrustLevel.blocked).toList();

  /// 初始化并载入本地信任列表
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefTrustListKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List list = jsonDecode(jsonStr) as List;
        for (final item in list) {
          final record = TrustRecord.fromJson(item as Map<String, dynamic>);
          _records[record.deviceId] = record;
        }
      } catch (e) {
        debugPrint('Failed to load trust records: $e');
      }
    }
  }

  /// 检查设备是否处于白名单授权状态
  bool isTrusted(String deviceId) {
    final record = _records[deviceId];
    return record != null && record.level == TrustLevel.trusted;
  }

  /// 检查设备是否设置了自动接收
  bool isAutoAccept(String deviceId) {
    final record = _records[deviceId];
    return record != null && record.level == TrustLevel.trusted && record.autoAccept;
  }

  /// 检查设备是否在黑名单
  bool isBlocked(String deviceId) {
    final record = _records[deviceId];
    return record != null && record.level == TrustLevel.blocked;
  }

  /// 获取设备信任记录
  TrustRecord? getRecord(String deviceId) => _records[deviceId];

  /// 添加或更新信任记录
  Future<void> saveRecord(TrustRecord record) async {
    _records[record.deviceId] = record;
    await _persist();
    notifyListeners();
  }

  /// 授权并加入白名单
  Future<void> authorizeDevice({
    required String deviceId,
    required String deviceName,
    required String fingerprint,
    bool autoAccept = true,
  }) async {
    final record = TrustRecord(
      deviceId: deviceId,
      deviceName: deviceName,
      fingerprint: fingerprint,
      level: TrustLevel.trusted,
      addedAt: DateTime.now(),
      autoAccept: autoAccept,
    );
    await saveRecord(record);
  }

  /// 修改自动接收设置
  Future<void> toggleAutoAccept(String deviceId, bool autoAccept) async {
    final record = _records[deviceId];
    if (record != null) {
      final updated = record.copyWith(autoAccept: autoAccept);
      await saveRecord(updated);
    }
  }

  /// 加入黑名单
  Future<void> blockDevice(String deviceId, String deviceName, String fingerprint) async {
    final record = TrustRecord(
      deviceId: deviceId,
      deviceName: deviceName,
      fingerprint: fingerprint,
      level: TrustLevel.blocked,
      addedAt: DateTime.now(),
      autoAccept: false,
    );
    await saveRecord(record);
  }

  /// 解除授权 / 移除信任
  Future<void> removeDevice(String deviceId) async {
    if (_records.containsKey(deviceId)) {
      _records.remove(deviceId);
      await _persist();
      notifyListeners();
    }
  }

  /// 持久化
  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _records.values.map((r) => r.toJson()).toList();
    await prefs.setString(_prefTrustListKey, jsonEncode(list));
  }
}
