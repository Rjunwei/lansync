import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/device_info.dart';
import 'network_utils.dart';
import 'security_service.dart';

/// 局域网设备探测与广播服务 (基于 UDP 广播)
class DiscoveryService extends ChangeNotifier {
  static const int discoveryPort = 53317;

  final SecurityService securityService;
  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  Timer? _cleanTimer;

  String _localIp = '127.0.0.1';
  bool _isGhostMode = false;
  final Map<String, DeviceInfo> _discoveredDevices = {};

  DiscoveryService({required this.securityService});

  String get localIp => _localIp;
  bool get isGhostMode => _isGhostMode;
  List<DeviceInfo> get onlineDevices => _discoveredDevices.values.toList();

  /// 启动设备发现服务
  Future<void> start() async {
    _localIp = await NetworkUtils.getLocalIp();

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
        reusePort: false,
      );
      _socket?.broadcastEnabled = true;

      _socket?.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram != null) {
            _handleDatagram(datagram);
          }
        }
      });

      // 立即广播一次
      broadcastPresence();

      // 每 5 秒定时心跳广播
      _broadcastTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        broadcastPresence();
      });

      // 每 3 秒清理超时 15 秒离线的设备
      _cleanTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _cleanOfflineDevices();
      });
    } catch (e) {
      debugPrint('DiscoveryService socket bind failed: $e');
    }
  }

  /// 发送局域网广播通知自身在线
  void broadcastPresence({bool isReply = false, InternetAddress? targetAddress}) {
    if (_isGhostMode && !isReply) return;
    if (_socket == null) return;

    final DevicePlatform currentPlatform;
    if (Platform.isWindows) {
      currentPlatform = DevicePlatform.windows;
    } else if (Platform.isLinux) {
      currentPlatform = DevicePlatform.linux;
    } else if (Platform.isAndroid) {
      currentPlatform = DevicePlatform.android;
    } else {
      currentPlatform = DevicePlatform.unknown;
    }

    final message = jsonEncode({
      'type': isReply ? 'PONG' : 'PING',
      'id': securityService.deviceId,
      'name': securityService.deviceName,
      'platform': currentPlatform.name,
      'ip': _localIp,
      'port': discoveryPort,
      'fingerprint': securityService.fingerprint,
    });

    final bytes = utf8.encode(message);

    try {
      if (targetAddress != null) {
        _socket?.send(bytes, targetAddress, discoveryPort);
      } else {
        _socket?.send(bytes, InternetAddress('255.255.255.255'), discoveryPort);
      }
    } catch (e) {
      debugPrint('Broadcast send error: $e');
    }
  }

  /// 处理收到的 UDP 数据报
  void _handleDatagram(Datagram datagram) {
    try {
      final text = utf8.decode(datagram.data);
      final json = jsonDecode(text) as Map<String, dynamic>;
      final type = json['type'] as String?;
      final senderId = json['id'] as String?;

      // 忽略自己发送的数据包
      if (senderId == null || senderId == securityService.deviceId) {
        return;
      }

      final senderIp = datagram.address.address;
      final device = DeviceInfo.fromJson(json, fallbackIp: senderIp);

      _discoveredDevices[device.id] = device;
      notifyListeners();

      // 如果收到的是 PING 探测，向对方单播回复一个 PONG
      if (type == 'PING') {
        broadcastPresence(isReply: true, targetAddress: datagram.address);
      }
    } catch (e) {
      debugPrint('Error parsing datagram: $e');
    }
  }

  /// 清理离线设备
  void _cleanOfflineDevices() {
    final now = DateTime.now();
    bool changed = false;

    _discoveredDevices.removeWhere((id, dev) {
      final diff = now.difference(dev.lastSeen).inSeconds;
      if (diff > 15) {
        changed = true;
        return true;
      }
      return false;
    });

    if (changed) {
      notifyListeners();
    }
  }

  /// 切换隐身模式
  void toggleGhostMode(bool enabled) {
    _isGhostMode = enabled;
    notifyListeners();
  }

  /// 停止服务
  void stop() {
    _broadcastTimer?.cancel();
    _cleanTimer?.cancel();
    _socket?.close();
    _socket = null;
  }
}
