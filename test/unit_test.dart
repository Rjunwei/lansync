import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_sync/models/device_info.dart';
import 'package:file_sync/models/transfer_item.dart';
import 'package:file_sync/services/security_service.dart';
import 'package:file_sync/services/trust_store_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecurityService Tests', () {
    test('generatePairingPin should return a 6-digit string', () {
      final security = SecurityService();
      final pin = security.generatePairingPin();
      expect(pin.length, 6);
      expect(int.tryParse(pin), isNotNull);
    });

    test('generatePairingToken should return non-empty base64 string', () {
      final security = SecurityService();
      final token = security.generatePairingToken();
      expect(token.isNotEmpty, true);
    });
  });

  group('TrustStoreService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('authorizeDevice adds device to trusted list', () async {
      final trustStore = TrustStoreService();
      await trustStore.init();

      expect(trustStore.isTrusted('dev-123'), false);

      await trustStore.authorizeDevice(
        deviceId: 'dev-123',
        deviceName: 'Test Phone',
        fingerprint: 'A1B2-C3D4',
        autoAccept: true,
      );

      expect(trustStore.isTrusted('dev-123'), true);
      expect(trustStore.isAutoAccept('dev-123'), true);
      expect(trustStore.trustedDevices.length, 1);

      // 解除授权
      await trustStore.removeDevice('dev-123');
      expect(trustStore.isTrusted('dev-123'), false);
    });
  });

  group('Model Serialization Tests', () {
    test('DeviceInfo JSON roundtrip', () {
      final dev = DeviceInfo(
        id: 'uuid-1',
        name: 'Ubuntu-Box',
        platform: DevicePlatform.linux,
        ip: '192.168.1.50',
        port: 53317,
        fingerprint: 'FF00-1122',
      );

      final json = dev.toJson();
      final restored = DeviceInfo.fromJson(json);

      expect(restored.id, dev.id);
      expect(restored.name, dev.name);
      expect(restored.platform, DevicePlatform.linux);
      expect(restored.ip, '192.168.1.50');
      expect(restored.fingerprint, 'FF00-1122');
    });

    test('TransferItem progress calculation', () {
      final item = TransferItem(
        id: 't-1',
        peerDeviceId: 'p-1',
        peerDeviceName: 'Peer',
        direction: TransferDirection.send,
        contentType: TransferContentType.file,
        fileName: 'video.mp4',
        totalBytes: 1000,
        transferredBytes: 500,
      );

      expect(item.progress, 0.5);
    });
  });
}
