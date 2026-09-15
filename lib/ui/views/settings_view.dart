import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../theme.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('系统设置', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 1. 设备名称卡片
          Card(
            child: ListTile(
              leading: const Icon(Icons.badge, color: AppTheme.primaryBlue),
              title: const Text('本机设备名称'),
              subtitle: Text(appState.myDeviceName),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _showEditNameDialog(context, appState),
            ),
          ),
          const SizedBox(height: 12),

          // 2. 默认存储目录卡片
          Card(
            child: ListTile(
              leading: const Icon(Icons.folder, color: AppTheme.secondaryCyan),
              title: const Text('文件默认接收保存目录'),
              subtitle: Text(appState.httpServerService.saveDirectory),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final selected = await FilePicker.platform.getDirectoryPath();
                if (selected != null) {
                  appState.httpServerService.setSaveDirectory(selected);
                }
              },
            ),
          ),
          const SizedBox(height: 12),

          // 3. 通信端口与协议
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.lan, color: AppTheme.accentGreen),
                  title: Text('网络传输端口'),
                  subtitle: Text('TCP/UDP 53317 (默认通信与广播端口)'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.fingerprint, color: Colors.purple),
                  title: const Text('本机安全指纹'),
                  subtitle: Text(appState.myFingerprint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. 防火墙配置说明卡片 (特别针对 Ubuntu 和 Windows)
          _buildFirewallGuideCard(context),
          const SizedBox(height: 16),

          // 5. 关于与软件版本
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset('assets/logo.png', width: 64, height: 64),
                ),
                const SizedBox(height: 12),
                Text(
                  'LanSync v1.0.0 (Pure Flutter)\n跨平台局域网安全互传系统',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirewallGuideCard(BuildContext context) {
    String commandTip = '';
    if (Platform.isLinux) {
      commandTip = 'Ubuntu 用户若发现无法接收广播，可运行:\n`sudo ufw allow 53317/tcp && sudo ufw allow 53317/udp`';
    } else if (Platform.isWindows) {
      commandTip = 'Windows 用户请在 Defender 防火墙允许 LanSync 通过专用/公用网络。';
    } else {
      commandTip = 'Android 手机需确保处于同一 Wi-Fi，且开启局域网设备互通。';
    }

    return Card(
      color: Colors.amber.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.security_update_warning, color: Colors.orange, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('局域网防火墙提示', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    commandTip,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, AppState appState) {
    final controller = TextEditingController(text: appState.myDeviceName);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('修改本机设备名称'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '如：我的办公室电脑',
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
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(ctx);
                  await appState.updateDeviceName(name);
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }
}
