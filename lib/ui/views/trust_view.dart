import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/device_info.dart';
import '../../models/trust_record.dart';
import '../../providers/app_state.dart';
import '../theme.dart';

class TrustView extends StatelessWidget {
  const TrustView({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final trustedList = appState.trustedDevices;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设备信任中心', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.qr_code, size: 18),
            label: const Text('生成配对二维码'),
            onPressed: () => _showPairingQrModal(context, appState),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: '手动添加设备',
            icon: const Icon(Icons.add_link),
            onPressed: () => _showManualAddDialog(context, appState),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 信任原则说明卡片
            _buildSecurityPolicyCard(context),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '已许可信任设备列表 (${trustedList.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (trustedList.isEmpty)
              _buildEmptyTrustState(context)
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: trustedList.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final record = trustedList[index];
                  return _buildTrustRecordTile(context, record, appState);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityPolicyCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user, color: AppTheme.primaryBlue, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '安全互信控制机制已启用',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  '只有被添加到下方信任列表中的设备，才可以向本机发送文件或读取共享数据。非授权设备的所有连接请求将在网络握手阶段被自动拦截。',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTrustState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          const Text(
            '尚未许可任何设备',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '点击右上角【生成配对二维码】，用手机或其他设备扫码即可安全互信绑定。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustRecordTile(BuildContext context, TrustRecord record, AppState appState) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppTheme.accentGreen.withValues(alpha: 0.15),
          child: const Icon(Icons.check_circle, color: AppTheme.accentGreen),
        ),
        title: Text(record.deviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('指纹: ${record.fingerprint}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  record.autoAccept ? '自动接收文件' : '接收前需弹窗确认',
                  style: TextStyle(
                    fontSize: 12,
                    color: record.autoAccept ? AppTheme.accentGreen : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: record.autoAccept ? '改为手动确认' : '改为自动接收',
              icon: Icon(
                record.autoAccept ? Icons.toggle_on : Icons.toggle_off,
                color: record.autoAccept ? AppTheme.accentGreen : Colors.grey,
                size: 32,
              ),
              onPressed: () {
                appState.trustStoreService.toggleAutoAccept(record.deviceId, !record.autoAccept);
              },
            ),
            IconButton(
              tooltip: '解除信任',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                await appState.unpairDevice(record.deviceId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已解除对 ${record.deviceName} 的许可')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 弹出二维码配对模态框
  void _showPairingQrModal(BuildContext context, AppState appState) {
    // 生成一个一次性配对 Token
    final token = appState.securityService.generatePairingToken();
    appState.httpServerService.setActivePairingToken(token);

    final payload = jsonEncode({
      'action': 'pair',
      'id': appState.myDeviceId,
      'name': appState.myDeviceName,
      'ip': appState.localIp,
      'port': 53317,
      'token': token,
      'fp': appState.myFingerprint,
    });

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('扫描二维码配对互信'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: QrImageView(
                  data: payload,
                  version: QrVersions.auto,
                  size: 220.0,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '在 Android 手机或另一台电脑上扫描此二维码，即可自动交换公钥并加入信任白名单。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                '本机指纹: ${appState.myFingerprint}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                appState.httpServerService.setActivePairingToken(null);
                Navigator.pop(ctx);
              },
              child: const Text('完成 / 关闭'),
            ),
          ],
        );
      },
    );
  }

  /// 手动输入 IP 添加
  void _showManualAddDialog(BuildContext context, AppState appState) {
    final ipController = TextEditingController();
    final nameController = TextEditingController(text: 'Remote Device');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('通过 IP 直连配对'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ipController,
                decoration: const InputDecoration(
                  labelText: '对方局域网 IP',
                  hintText: '如 192.168.1.108',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '备注设备名',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final ip = ipController.text.trim();
                final name = nameController.text.trim();
                if (ip.isNotEmpty) {
                  Navigator.pop(ctx);
                  final tempDev = DeviceInfo(
                    id: 'manual-$ip',
                    name: name,
                    platform: DevicePlatform.unknown,
                    ip: ip,
                    port: 53317,
                    fingerprint: 'MANUAL',
                  );
                  final ok = await appState.pairWithDevice(tempDev);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? '配对成功！' : '连接超时或对方拒绝')),
                    );
                  }
                }
              },
              child: const Text('发起配对'),
            ),
          ],
        );
      },
    );
  }
}
