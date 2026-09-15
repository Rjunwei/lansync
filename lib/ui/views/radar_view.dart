import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/device_info.dart';
import '../../providers/app_state.dart';
import '../theme.dart';

class RadarView extends StatelessWidget {
  const RadarView({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设备雷达与互传', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: '重新探测局域网',
            icon: const Icon(Icons.refresh),
            onPressed: () => appState.refreshDiscovery(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 本机设备状态条
            _buildMyDeviceCard(context, appState, isDark),
            const SizedBox(height: 24),

            // 2. 局域网设备雷达
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.radar, color: AppTheme.primaryBlue),
                    const SizedBox(width: 8),
                    Text(
                      '发现的局域网设备 (${appState.onlineDevices.length})',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  appState.isGhostMode ? '已开启隐身' : '正常探测中',
                  style: TextStyle(
                    fontSize: 13,
                    color: appState.isGhostMode ? Colors.grey : AppTheme.accentGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (appState.onlineDevices.isEmpty)
              _buildEmptyDeviceState(context)
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 380,
                  mainAxisExtent: 140,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: appState.onlineDevices.length,
                itemBuilder: (context, index) {
                  final dev = appState.onlineDevices[index];
                  final isTrusted = appState.isDeviceTrusted(dev.id);
                  return _buildDeviceCard(context, dev, isTrusted, appState);
                },
              ),

            const SizedBox(height: 32),

            // 3. 快速投送区提示
            _buildDropZoneTip(context),
          ],
        ),
      ),
    );
  }

  /// 本机设备卡片
  Widget _buildMyDeviceCard(BuildContext context, AppState appState, bool isDark) {
    return Card(
      color: isDark ? const Color(0xFF1E2638) : const Color(0xFFEBF2FF),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
              child: const Icon(Icons.devices, color: AppTheme.primaryBlue, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        appState.myDeviceName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '本机',
                          style: TextStyle(fontSize: 11, color: AppTheme.accentGreen, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'IP: ${appState.localIp}   安全指纹: ${appState.myFingerprint}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            // 隐身模式开关
            Column(
              children: [
                Switch(
                  value: !appState.isGhostMode,
                  activeThumbColor: AppTheme.primaryBlue,
                  onChanged: (val) => appState.toggleGhostMode(!val),
                ),
                Text(
                  appState.isGhostMode ? '隐身中' : '可被发现',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 无设备提示
  Widget _buildEmptyDeviceState(BuildContext context) {
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
          const Icon(Icons.wifi_tethering, size: 54, color: Colors.grey),
          const SizedBox(height: 12),
          const Text(
            '正在扫描局域网中的设备...',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            '请确保其他设备连接在同一 Wi-Fi 或局域网路由器下，且已启动 LanSync',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  /// 单个发现的设备卡片
  Widget _buildDeviceCard(
    BuildContext context,
    DeviceInfo dev,
    bool isTrusted,
    AppState appState,
  ) {
    IconData platformIcon;
    switch (dev.platform) {
      case DevicePlatform.windows:
        platformIcon = Icons.window;
        break;
      case DevicePlatform.linux:
        platformIcon = Icons.terminal;
        break;
      case DevicePlatform.android:
        platformIcon = Icons.android;
        break;
      default:
        platformIcon = Icons.devices_other;
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDeviceActionSheet(context, dev, isTrusted, appState),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isTrusted
                        ? AppTheme.accentGreen.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                    child: Icon(
                      platformIcon,
                      color: isTrusted ? AppTheme.accentGreen : Colors.orange,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dev.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          '${dev.ip} (${dev.fingerprint})',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  // 信任状态徽标
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isTrusted
                          ? AppTheme.accentGreen.withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isTrusted ? '已信任' : '未授权',
                      style: TextStyle(
                        fontSize: 11,
                        color: isTrusted ? AppTheme.accentGreen : Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isTrusted)
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.lock_open, size: 16),
                      label: const Text('授权配对'),
                      onPressed: () => _triggerPairing(context, dev, appState),
                    )
                  else
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.send, size: 16),
                      label: const Text('发送文件'),
                      onPressed: () => _pickAndSendFile(context, dev, appState),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 点击设备弹出操作选择
  void _showDeviceActionSheet(
    BuildContext context,
    DeviceInfo dev,
    bool isTrusted,
    AppState appState,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.devices, color: AppTheme.primaryBlue),
                  title: Text(dev.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('IP: ${dev.ip} | 安全指纹: ${dev.fingerprint}'),
                  trailing: Chip(
                    label: Text(isTrusted ? '已授权设备' : '未许可设备'),
                    backgroundColor: isTrusted
                        ? AppTheme.accentGreen.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                  ),
                ),
                const Divider(),
                if (isTrusted) ...[
                  ListTile(
                    leading: const Icon(Icons.insert_drive_file, color: AppTheme.primaryBlue),
                    title: const Text('发送文件'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendFile(context, dev, appState);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.notes, color: AppTheme.secondaryCyan),
                    title: const Text('发送文本 / 链接'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showSendTextDialog(context, dev, appState);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text('解除设备授权', style: TextStyle(color: Colors.red)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await appState.unpairDevice(dev.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已移除对 ${dev.name} 的授权')),
                        );
                      }
                    },
                  ),
                ] else ...[
                  ListTile(
                    leading: const Icon(Icons.security, color: Colors.orange),
                    title: const Text('向该设备申请配对许可'),
                    subtitle: const Text('需要双方核对屏幕 PIN 码或拥有扫码 Token'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _triggerPairing(context, dev, appState);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// 触发配对申请
  Future<void> _triggerPairing(
    BuildContext context,
    DeviceInfo dev,
    AppState appState,
  ) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('正在向 ${dev.name} 发起配对申请，请在对方屏幕上确认...')),
    );

    final success = await appState.pairWithDevice(dev);
    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.accentGreen,
          content: Text('与 ${dev.name} 配对成功！已加入受信任白名单。'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('配对被拒绝或请求超时。'),
        ),
      );
    }
  }

  /// 选择文件并发送
  Future<void> _pickAndSendFile(
    BuildContext context,
    DeviceInfo dev,
    AppState appState,
  ) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null && result.files.isNotEmpty) {
      for (final platformFile in result.files) {
        if (platformFile.path != null) {
          final file = File(platformFile.path!);
          appState.sendFileToDevice(dev, file);
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已添加 ${result.files.length} 个文件到传输队列')),
        );
      }
    }
  }

  /// 发送文本对话框
  void _showSendTextDialog(BuildContext context, DeviceInfo dev, AppState appState) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('向 ${dev.name} 发送文本/URL'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '输入要同步的文本、备忘录或网址...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(ctx);
                  final ok = await appState.sendTextToDevice(dev, text);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? '发送成功！' : '发送失败，请检查对端状态')),
                    );
                  }
                }
              },
              child: const Text('发送'),
            ),
          ],
        );
      },
    );
  }

  /// 底部快速拖拽投送提示卡片
  Widget _buildDropZoneTip(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        children: [
          const Icon(Icons.upload_file, size: 40, color: AppTheme.primaryBlue),
          const SizedBox(height: 8),
          const Text(
            '安全互传：点击上方已信任设备即可立即投送',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            '仅自己许可的白名单设备之间允许互传，任何未授权陌生设备将被底层自动拦截。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
