import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../models/device_info.dart';
import '../models/transfer_event.dart';
import '../models/transfer_item.dart';
import 'security_service.dart';

/// 传输客户端服务 (负责主动发起配对与流式上传)
class TransferClientService extends ChangeNotifier {
  final SecurityService securityService;
  final Map<String, TransferItem> _outgoingTransfers = {};

  // 全局传输生命周期事件流
  final StreamController<TransferEvent> _eventController = StreamController<TransferEvent>.broadcast();
  Stream<TransferEvent> get transferEvents => _eventController.stream;

  TransferClientService({required this.securityService});

  List<TransferItem> get outgoingTransfers => _outgoingTransfers.values.toList().reversed.toList();

  /// 向目标设备发起安全配对请求
  Future<bool> requestPairing(DeviceInfo target, {String? token, String? pin}) async {
    final url = Uri.parse('http://${target.ip}:${target.port}/api/v1/pair/request');
    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'deviceId': securityService.deviceId,
              'deviceName': securityService.deviceName,
              'fingerprint': securityService.fingerprint,
              'token': token,
              'pin': pin,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['status'] == 'approved';
      }
      return false;
    } catch (e) {
      debugPrint('Pairing request failed: $e');
      return false;
    }
  }

  /// 通知目标设备解除配对授权 (双向同步解绑)
  Future<bool> notifyUnpair(DeviceInfo target) async {
    final url = Uri.parse('http://${target.ip}:${target.port}/api/v1/unpair');
    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'deviceId': securityService.deviceId}),
      ).timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('notifyUnpair failed: $e');
      return false;
    }
  }

  /// 发送单文件
  Future<bool> sendFile(DeviceInfo target, File file) async {
    final fileName = p.basename(file.path);
    final totalBytes = await file.length();
    final fileId = DateTime.now().millisecondsSinceEpoch.toString();

    String transferToken = '';

    // 1. 握手检查对方是否授权接收
    final handshakeUrl = Uri.parse('http://${target.ip}:${target.port}/api/v1/transfer/handshake');
    try {
      final handshakeRes = await http
          .post(
            handshakeUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'fileId': fileId,
              'deviceId': securityService.deviceId,
              'deviceName': securityService.deviceName,
              'fileName': fileName,
              'totalBytes': totalBytes,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (handshakeRes.statusCode != 200) {
        debugPrint('Handshake rejected or unauthorized: ${handshakeRes.statusCode} - ${handshakeRes.body}');
        final isRejected = handshakeRes.statusCode == 403;
        final errorMsg = isRejected ? '对方拒绝了文件接收请求' : '设备未授权或拒绝连接 (${handshakeRes.statusCode})';

        final failedItem = TransferItem(
          id: fileId,
          peerDeviceId: target.id,
          peerDeviceName: target.name,
          direction: TransferDirection.send,
          contentType: TransferContentType.file,
          fileName: fileName,
          totalBytes: totalBytes,
          localPath: file.path,
          status: TransferStatus.failed,
          error: errorMsg,
        );
        _outgoingTransfers[fileId] = failedItem;
        notifyListeners();

        _eventController.add(TransferEvent(
          type: isRejected ? TransferEventType.rejected : TransferEventType.failed,
          item: failedItem,
          message: errorMsg,
        ));
        return false;
      }

      final handshakeData = jsonDecode(handshakeRes.body) as Map<String, dynamic>;
      transferToken = handshakeData['token'] as String? ?? '';
    } catch (e) {
      debugPrint('Handshake failed: $e');
      final failedItem = TransferItem(
        id: fileId,
        peerDeviceId: target.id,
        peerDeviceName: target.name,
        direction: TransferDirection.send,
        contentType: TransferContentType.file,
        fileName: fileName,
        totalBytes: totalBytes,
        localPath: file.path,
        status: TransferStatus.failed,
        error: '网络连接失败，请确认对端设备在线且在同一局域网',
      );
      _outgoingTransfers[fileId] = failedItem;
      notifyListeners();

      _eventController.add(TransferEvent(
        type: TransferEventType.failed,
        item: failedItem,
        message: '连接 ${target.name} 失败: 设备离线或网络不可达',
      ));
      return false;
    }

    // 2. 流式上传数据
    final uploadUrl = Uri.parse('http://${target.ip}:${target.port}/api/v1/transfer/upload');
    final transferItem = TransferItem(
      id: fileId,
      peerDeviceId: target.id,
      peerDeviceName: target.name,
      direction: TransferDirection.send,
      contentType: TransferContentType.file,
      fileName: fileName,
      totalBytes: totalBytes,
      localPath: file.path,
      status: TransferStatus.transferring,
    );

    _outgoingTransfers[fileId] = transferItem;
    notifyListeners();

    _eventController.add(TransferEvent(
      type: TransferEventType.started,
      item: transferItem,
      message: '正在向 ${target.name} 发送 $fileName...',
    ));

    try {
      final request = http.StreamedRequest('POST', uploadUrl);
      request.headers['x-file-id'] = fileId;
      request.headers['x-device-id'] = securityService.deviceId;
      request.headers['x-device-name'] = securityService.deviceName;
      request.headers['x-file-name'] = base64Encode(utf8.encode(fileName));
      request.headers['x-total-bytes'] = totalBytes.toString();
      request.headers['x-transfer-token'] = transferToken;

      final fileStream = file.openRead();
      var lastTime = DateTime.now();
      var lastTransferred = 0;

      // 异步推送文件流并统计进度
      final streamFuture = () async {
        await for (final chunk in fileStream) {
          request.sink.add(chunk);
          transferItem.transferredBytes += chunk.length;

          final now = DateTime.now();
          final duration = now.difference(lastTime).inMilliseconds;
          if (duration >= 500) {
            final deltaBytes = transferItem.transferredBytes - lastTransferred;
            transferItem.speedBytesPerSec = (deltaBytes / (duration / 1000.0));
            lastTime = now;
            lastTransferred = transferItem.transferredBytes;
            notifyListeners();
          }
        }
        await request.sink.close();
      }();

      final response = await request.send();
      await streamFuture;

      if (response.statusCode == 200) {
        transferItem.status = TransferStatus.completed;
        transferItem.speedBytesPerSec = 0;
        notifyListeners();

        _eventController.add(TransferEvent(
          type: TransferEventType.completed,
          item: transferItem,
          message: '文件 $fileName 已成功发送给 ${target.name}！',
          localPath: file.path,
        ));
        return true;
      } else {
        transferItem.status = TransferStatus.failed;
        transferItem.error = '目标设备返回错误 (HTTP ${response.statusCode})';
        notifyListeners();

        _eventController.add(TransferEvent(
          type: TransferEventType.failed,
          item: transferItem,
          message: '向 ${target.name} 发送 $fileName 失败: HTTP ${response.statusCode}',
        ));
        return false;
      }
    } catch (e) {
      transferItem.status = TransferStatus.failed;
      transferItem.error = e.toString();
      notifyListeners();

      _eventController.add(TransferEvent(
        type: TransferEventType.failed,
        item: transferItem,
        message: '向 ${target.name} 发送 $fileName 失败: $e',
      ));
      return false;
    }
  }

  /// 发送纯文本/URL
  Future<bool> sendText(DeviceInfo target, String text) async {
    final url = Uri.parse('http://${target.ip}:${target.port}/api/v1/transfer/text');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'deviceId': securityService.deviceId,
          'deviceName': securityService.deviceName,
          'text': text,
        }),
      );

      final ok = response.statusCode == 200;
      if (ok) {
        final textItem = TransferItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          peerDeviceId: target.id,
          peerDeviceName: target.name,
          direction: TransferDirection.send,
          contentType: TransferContentType.text,
          fileName: 'Text Note',
          totalBytes: text.length,
          transferredBytes: text.length,
          textContent: text,
          status: TransferStatus.completed,
        );
        _outgoingTransfers[textItem.id] = textItem;
        notifyListeners();

        _eventController.add(TransferEvent(
          type: TransferEventType.completed,
          item: textItem,
          message: '已向 ${target.name} 发送文本消息',
        ));
      }
      return ok;
    } catch (e) {
      debugPrint('Send text failed: $e');
      return false;
    }
  }

  /// 清除已完成或失败的历史传输记录
  void clearTransfers() {
    _outgoingTransfers.removeWhere((_, item) =>
        item.status == TransferStatus.completed ||
        item.status == TransferStatus.failed ||
        item.status == TransferStatus.canceled);
    notifyListeners();
  }

  @override
  void dispose() {
    _eventController.close();
    super.dispose();
  }
}
