import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import '../models/transfer_event.dart';
import '../models/transfer_item.dart';
import 'security_service.dart';
import 'trust_store_service.dart';

/// 待确认的配对请求
class PendingPairRequest {
  final String deviceId;
  final String deviceName;
  final String fingerprint;
  final String pin;
  final Completer<bool> completer;

  PendingPairRequest({
    required this.deviceId,
    required this.deviceName,
    required this.fingerprint,
    required this.pin,
    required this.completer,
  });
}

/// 待确认的文件接收请求
class PendingTransferRequest {
  final String fileId;
  final String deviceId;
  final String deviceName;
  final String fileName;
  final int totalBytes;
  final Completer<bool> completer;

  PendingTransferRequest({
    required this.fileId,
    required this.deviceId,
    required this.deviceName,
    required this.fileName,
    required this.totalBytes,
    required this.completer,
  });
}

/// 内置 Shelf HTTP 传输服务端
class HttpServerService extends ChangeNotifier {
  static const int httpPort = 53317;

  final SecurityService securityService;
  final TrustStoreService trustStoreService;
  HttpServer? _server;

  String _saveDirectory = '';
  String? _activePairingToken; // 当前屏幕二维码生成的临时配对 Token

  // 待用户交互确认的配对与传输通知
  PendingPairRequest? _currentPendingPair;
  PendingTransferRequest? _currentPendingTransfer;

  // 正在接收的任务
  final Map<String, TransferItem> _activeTransfers = {};

  // 授权的传输会话 Token: fileId -> sessionToken
  final Map<String, String> _authorizedTransferSessions = {};

  // 全局传输生命周期事件流
  final StreamController<TransferEvent> _eventController = StreamController<TransferEvent>.broadcast();
  Stream<TransferEvent> get transferEvents => _eventController.stream;

  HttpServerService({
    required this.securityService,
    required this.trustStoreService,
  });

  PendingPairRequest? get currentPendingPair => _currentPendingPair;
  PendingTransferRequest? get currentPendingTransfer => _currentPendingTransfer;
  String get saveDirectory => _saveDirectory;

  /// 设置保存路径
  void setSaveDirectory(String dir) {
    _saveDirectory = dir;
    notifyListeners();
  }

  /// 设置当前扫码配对 Token
  void setActivePairingToken(String? token) {
    _activePairingToken = token;
  }

  /// 启动 HTTP 服务
  Future<void> start() async {
    if (_saveDirectory.isEmpty) {
      // 默认保存路径为用户 Downloads 或当前目录
      if (Platform.isLinux || Platform.isWindows) {
        final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
        _saveDirectory = p.join(home, 'Downloads', 'LanSync');
      } else {
        _saveDirectory = '/sdcard/Download/LanSync';
      }
      final dir = Directory(_saveDirectory);
      if (!await dir.exists()) {
        try {
          await dir.create(recursive: true);
        } catch (_) {}
      }
    }

    final app = Router();

    // 1. 获取本机设备信息
    app.get('/api/v1/info', (Request request) {
      final info = {
        'id': securityService.deviceId,
        'name': securityService.deviceName,
        'fingerprint': securityService.fingerprint,
        'port': httpPort,
      };
      return Response.ok(
        jsonEncode(info),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // 2. 接收对端发来的解除授权通知
    app.post('/api/v1/unpair', (Request request) async {
      try {
        final payload = await request.readAsString();
        final data = jsonDecode(payload) as Map<String, dynamic>;
        final devId = data['deviceId'] as String?;
        if (devId != null && devId.isNotEmpty) {
          await trustStoreService.removeDevice(devId);
          notifyListeners();
          return Response.ok(
            jsonEncode({'status': 'unpaired', 'deviceId': devId}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      } catch (e) {
        debugPrint('Handle unpair error: $e');
      }
      return Response.badRequest(body: jsonEncode({'error': 'Invalid deviceId'}));
    });

    // 3. 发起配对请求
    app.post('/api/v1/pair/request', (Request request) async {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final devId = data['deviceId'] as String? ?? '';
      final devName = data['deviceName'] as String? ?? 'Device';
      final fp = data['fingerprint'] as String? ?? '';
      final token = data['token'] as String?;
      final pin = data['pin'] as String?;

      if (trustStoreService.isBlocked(devId)) {
        return Response.forbidden(jsonEncode({'error': 'Device is blocked'}));
      }

      // 场景 A: 对方携带了正确的扫码 Token
      if (_activePairingToken != null && token != null && token == _activePairingToken) {
        await trustStoreService.authorizeDevice(
          deviceId: devId,
          deviceName: devName,
          fingerprint: fp,
          autoAccept: true,
        );
        _activePairingToken = null; // 用完即作废
        return Response.ok(jsonEncode({'status': 'approved', 'type': 'qr_token'}));
      }

      // 场景 B: 弹窗核验 6 位 PIN 码
      final completer = Completer<bool>();
      _currentPendingPair = PendingPairRequest(
        deviceId: devId,
        deviceName: devName,
        fingerprint: fp,
        pin: pin ?? securityService.generatePairingPin(),
        completer: completer,
      );
      notifyListeners();

      final accepted = await completer.future;
      _currentPendingPair = null;
      notifyListeners();

      if (accepted) {
        await trustStoreService.authorizeDevice(
          deviceId: devId,
          deviceName: devName,
          fingerprint: fp,
          autoAccept: true,
        );
        return Response.ok(jsonEncode({'status': 'approved'}));
      } else {
        return Response.forbidden(jsonEncode({'status': 'rejected'}));
      }
    });

    // 3. 传输前握手检查
    app.post('/api/v1/transfer/handshake', (Request request) async {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final senderId = data['deviceId'] as String? ?? '';
      final senderName = data['deviceName'] as String? ?? 'Device';
      final fileName = data['fileName'] as String? ?? 'unknown';
      final totalBytes = data['totalBytes'] as int? ?? 0;
      final fileId = data['fileId'] as String? ?? '';

      // 核心授权安全拦截：未许可设备直接拒绝！
      if (!trustStoreService.isTrusted(senderId)) {
        return Response.forbidden(jsonEncode({
          'error': 'Unauthorized',
          'message': '该设备尚未获得您的授权许可，传输已被拒绝。',
        }));
      }

      // 生成单次传输会话安全 Token
      final sessionToken = securityService.generatePairingToken();
      _authorizedTransferSessions[fileId] = sessionToken;

      // 如果开启了受信任设备自动接收
      if (trustStoreService.isAutoAccept(senderId)) {
        return Response.ok(jsonEncode({'accepted': true, 'token': sessionToken}));
      }

      // 否则触发本地用户弹窗询问
      final completer = Completer<bool>();
      _currentPendingTransfer = PendingTransferRequest(
        fileId: fileId,
        deviceId: senderId,
        deviceName: senderName,
        fileName: p.basename(fileName),
        totalBytes: totalBytes,
        completer: completer,
      );
      notifyListeners();

      final accepted = await completer.future;
      _currentPendingTransfer = null;
      notifyListeners();

      if (accepted) {
        return Response.ok(jsonEncode({'accepted': true, 'token': sessionToken}));
      } else {
        _authorizedTransferSessions.remove(fileId);
        return Response.forbidden(jsonEncode({'accepted': false}));
      }
    });

    // 4. 流式上传二进制数据
    app.post('/api/v1/transfer/upload', (Request request) async {
      final senderId = request.headers['x-device-id'] ?? '';
      final senderName = request.headers['x-device-name'] ?? 'Device';
      final rawFileName = request.headers['x-file-name'] != null
          ? utf8.decode(base64Decode(request.headers['x-file-name']!))
          : 'received_file';
      // 关键安全防御: 消除路径遍历 (Path Traversal) 风险
      final fileName = p.basename(rawFileName);

      final totalBytes = int.tryParse(request.headers['x-total-bytes'] ?? '0') ?? 0;
      final fileId = request.headers['x-file-id'] ?? '';
      final transferToken = request.headers['x-transfer-token'] ?? '';

      // 安全拦截 1: 验证发起设备是否属于信任白名单
      if (!trustStoreService.isTrusted(senderId)) {
        return Response.forbidden('Unauthorized device');
      }

      // 安全拦截 2: 严格核验本次传输的单次握手 Token (防 Header 伪造)
      final expectedToken = _authorizedTransferSessions[fileId];
      if (expectedToken == null || expectedToken != transferToken) {
        return Response.forbidden('Invalid or expired transfer session token');
      }
      _authorizedTransferSessions.remove(fileId); // 校验通过即销毁

      final targetDir = Directory(_saveDirectory);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // 处理文件名防重名
      String filePath = p.join(_saveDirectory, fileName);
      if (await File(filePath).exists()) {
        final ext = p.extension(fileName);
        final base = p.basenameWithoutExtension(fileName);
        filePath = p.join(_saveDirectory, '$base-${DateTime.now().millisecondsSinceEpoch}$ext');
      }

      final file = File(filePath);
      final sink = file.openWrite();

      final transferItem = TransferItem(
        id: fileId,
        peerDeviceId: senderId,
        peerDeviceName: senderName,
        direction: TransferDirection.receive,
        contentType: TransferContentType.file,
        fileName: p.basename(filePath),
        totalBytes: totalBytes,
        localPath: filePath,
        status: TransferStatus.transferring,
      );

      _activeTransfers[fileId] = transferItem;
      notifyListeners();
      _eventController.add(TransferEvent(
        type: TransferEventType.started,
        item: transferItem,
        message: '正在接收来自 $senderName 的 ${transferItem.fileName}...',
      ));

      var lastTime = DateTime.now();
      var lastTransferred = 0;

      try {
        await for (final chunk in request.read()) {
          sink.add(chunk);
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
        await sink.flush();
        await sink.close();

        transferItem.status = TransferStatus.completed;
        transferItem.speedBytesPerSec = 0;
        notifyListeners();
        _eventController.add(TransferEvent(
          type: TransferEventType.completed,
          item: transferItem,
          message: '成功接收文件 ${transferItem.fileName}！',
          localPath: filePath,
        ));

        return Response.ok(jsonEncode({'status': 'success', 'savedPath': filePath}));
      } catch (e) {
        await sink.close();
        transferItem.status = TransferStatus.failed;
        transferItem.error = e.toString();
        notifyListeners();
        _eventController.add(TransferEvent(
          type: TransferEventType.failed,
          item: transferItem,
          message: '接收 ${transferItem.fileName} 失败: $e',
        ));
        return Response.internalServerError(body: 'Error writing file: $e');
      }
    });

    // 5. 纯文本/URL接收
    app.post('/api/v1/transfer/text', (Request request) async {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final senderId = data['deviceId'] as String? ?? '';
      final senderName = data['deviceName'] as String? ?? 'Device';
      final text = data['text'] as String? ?? '';

      // 安全拦截
      if (!trustStoreService.isTrusted(senderId)) {
        return Response.forbidden('Unauthorized device');
      }

      final transferItem = TransferItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        peerDeviceId: senderId,
        peerDeviceName: senderName,
        direction: TransferDirection.receive,
        contentType: TransferContentType.text,
        fileName: 'Text Note',
        totalBytes: text.length,
        transferredBytes: text.length,
        textContent: text,
        status: TransferStatus.completed,
      );

      _activeTransfers[transferItem.id] = transferItem;
      notifyListeners();
      _eventController.add(TransferEvent(
        type: TransferEventType.completed,
        item: transferItem,
        message: '收到来自 $senderName 的文本: ${text.length > 25 ? '${text.substring(0, 25)}...' : text}',
      ));

      return Response.ok(jsonEncode({'status': 'success'}));
    });

    try {
      _server = await shelf_io.serve(app.call, InternetAddress.anyIPv4, httpPort);
      debugPrint('HttpServer started on port $httpPort');
    } catch (e) {
      debugPrint('HttpServer bind failed: $e');
    }
  }

  /// 用户确认或拒绝配对
  void resolvePairing(bool approved) {
    _currentPendingPair?.completer.complete(approved);
  }

  /// 用户确认或拒绝文件接收
  void resolveTransfer(bool approved) {
    _currentPendingTransfer?.completer.complete(approved);
  }

  /// 获取传输列表
  List<TransferItem> get allTransfers => _activeTransfers.values.toList().reversed.toList();

  /// 清除已完成或失败的历史传输记录
  void clearTransfers() {
    _activeTransfers.removeWhere((_, item) =>
        item.status == TransferStatus.completed ||
        item.status == TransferStatus.failed ||
        item.status == TransferStatus.canceled);
    notifyListeners();
  }

  /// 停止服务
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    await _eventController.close();
  }
}
