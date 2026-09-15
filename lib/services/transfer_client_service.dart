import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../models/device_info.dart';
import '../models/transfer_item.dart';
import 'security_service.dart';

/// 传输客户端服务 (负责主动发起配对与流式上传)
class TransferClientService extends ChangeNotifier {
  final SecurityService securityService;
  final Map<String, TransferItem> _outgoingTransfers = {};

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

  /// 发送单文件
  Future<bool> sendFile(DeviceInfo target, File file) async {
    final fileName = p.basename(file.path);
    final totalBytes = await file.length();
    final fileId = DateTime.now().millisecondsSinceEpoch.toString();

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
        return false;
      }
    } catch (e) {
      debugPrint('Handshake failed: $e');
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

    try {
      final request = http.StreamedRequest('POST', uploadUrl);
      request.headers['x-file-id'] = fileId;
      request.headers['x-device-id'] = securityService.deviceId;
      request.headers['x-device-name'] = securityService.deviceName;
      request.headers['x-file-name'] = base64Encode(utf8.encode(fileName));
      request.headers['x-total-bytes'] = totalBytes.toString();

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
        return true;
      } else {
        transferItem.status = TransferStatus.failed;
        transferItem.error = 'Server returned ${response.statusCode}';
        notifyListeners();
        return false;
      }
    } catch (e) {
      transferItem.status = TransferStatus.failed;
      transferItem.error = e.toString();
      notifyListeners();
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

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Send text failed: $e');
      return false;
    }
  }
}
