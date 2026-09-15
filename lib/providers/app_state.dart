import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/device_info.dart';
import '../models/transfer_event.dart';
import '../models/transfer_item.dart';
import '../models/trust_record.dart';
import '../services/discovery_service.dart';
import '../services/http_server_service.dart';
import '../services/security_service.dart';
import '../services/transfer_client_service.dart';
import '../services/trust_store_service.dart';

/// 全局应用状态聚合与业务控制中心
class AppState extends ChangeNotifier {
  final SecurityService securityService = SecurityService();
  final TrustStoreService trustStoreService = TrustStoreService();
  late final DiscoveryService discoveryService;
  late final HttpServerService httpServerService;
  late final TransferClientService transferClientService;

  final StreamController<TransferEvent> _transferEventController = StreamController<TransferEvent>.broadcast();
  Stream<TransferEvent> get transferEvents => _transferEventController.stream;

  StreamSubscription<TransferEvent>? _httpServerSub;
  StreamSubscription<TransferEvent>? _clientSub;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  AppState() {
    discoveryService = DiscoveryService(securityService: securityService);
    httpServerService = HttpServerService(
      securityService: securityService,
      trustStoreService: trustStoreService,
    );
    transferClientService = TransferClientService(securityService: securityService);

    // 监听子服务的状态变动，统一触发 UI 刷新
    discoveryService.addListener(notifyListeners);
    httpServerService.addListener(notifyListeners);
    trustStoreService.addListener(notifyListeners);
    transferClientService.addListener(notifyListeners);

    // 转发各端生命周期事件到全局流
    _httpServerSub = httpServerService.transferEvents.listen(_transferEventController.add);
    _clientSub = transferClientService.transferEvents.listen(_transferEventController.add);
  }

  /// 全局初始化并启动服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await securityService.init();
      await trustStoreService.init();
      await httpServerService.start();
      await discoveryService.start();
    } catch (e, st) {
      debugPrint('AppState initialize error: $e\n$st');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  // 快捷获取属性
  String get myDeviceName => securityService.deviceName;
  String get myDeviceId => securityService.deviceId;
  String get myFingerprint => securityService.fingerprint;
  String get localIp => discoveryService.localIp;
  bool get isGhostMode => discoveryService.isGhostMode;
  List<DeviceInfo> get onlineDevices => discoveryService.onlineDevices;
  List<TrustRecord> get trustedDevices => trustStoreService.trustedDevices;

  /// 在线且已授权的设备列表
  List<DeviceInfo> get trustedOnlineDevices =>
      onlineDevices.where((d) => isDeviceTrusted(d.id)).toList();

  /// 获取合并后的所有传输任务（接收 + 发送，按时间倒序）
  List<TransferItem> get allTransfers {
    final list = <TransferItem>[
      ...httpServerService.allTransfers,
      ...transferClientService.outgoingTransfers,
    ];
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// 正在传输中的任务列表
  List<TransferItem> get activeTransfers =>
      allTransfers.where((t) => t.status == TransferStatus.transferring).toList();

  /// 当前瞬时总传输速度 (Bytes/sec)
  double get totalTransferSpeed =>
      activeTransfers.fold(0.0, (sum, t) => sum + t.speedBytesPerSec);

  /// 检查设备是否信任
  bool isDeviceTrusted(String deviceId) => trustStoreService.isTrusted(deviceId);

  /// 手动广播刷新
  void refreshDiscovery() {
    discoveryService.broadcastPresence();
  }

  /// 切换隐身模式
  void toggleGhostMode(bool enabled) {
    discoveryService.toggleGhostMode(enabled);
  }

  /// 更新本机名称
  Future<void> updateDeviceName(String newName) async {
    await securityService.updateDeviceName(newName);
    discoveryService.broadcastPresence();
    notifyListeners();
  }

  /// 发送文件给目标设备
  Future<bool> sendFileToDevice(DeviceInfo target, File file) async {
    return await transferClientService.sendFile(target, file);
  }

  /// 发送文本给目标设备
  Future<bool> sendTextToDevice(DeviceInfo target, String text) async {
    return await transferClientService.sendText(target, text);
  }

  /// 清理已完成或失败的历史传输记录
  void clearTransferHistory() {
    httpServerService.clearTransfers();
    transferClientService.clearTransfers();
    notifyListeners();
  }

  /// 发起配对申请
  Future<bool> pairWithDevice(DeviceInfo target, {String? token, String? pin}) async {
    final success = await transferClientService.requestPairing(target, token: token, pin: pin);
    if (success) {
      await trustStoreService.authorizeDevice(
        deviceId: target.id,
        deviceName: target.name,
        fingerprint: target.fingerprint,
        autoAccept: true,
      );
    }
    return success;
  }

  /// 解除设备信任 (双向解绑)
  Future<void> unpairDevice(String deviceId) async {
    // 1. 如果对端在线，发送 HTTP 解除通知
    final onlineTarget = onlineDevices.where((d) => d.id == deviceId).firstOrNull;
    if (onlineTarget != null) {
      transferClientService.notifyUnpair(onlineTarget);
    }
    // 2. 本地移除信任
    await trustStoreService.removeDevice(deviceId);
    notifyListeners();
  }

  @override
  void dispose() {
    discoveryService.removeListener(notifyListeners);
    httpServerService.removeListener(notifyListeners);
    trustStoreService.removeListener(notifyListeners);
    transferClientService.removeListener(notifyListeners);

    _httpServerSub?.cancel();
    _clientSub?.cancel();
    _transferEventController.close();

    discoveryService.stop();
    httpServerService.stop();
    super.dispose();
  }
}
