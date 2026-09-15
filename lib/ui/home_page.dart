import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/http_server_service.dart';
import 'theme.dart';
import 'views/radar_view.dart';
import 'views/settings_view.dart';
import 'views/transfer_view.dart';
import 'views/trust_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  bool _isPairingDialogShowing = false;
  bool _isTransferDialogShowing = false;

  final List<Widget> _views = const [
    RadarView(),
    TransferView(),
    TrustView(),
    SettingsView(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkIncomingRequests();
  }

  /// 监听网络端待处理的配对或接收请求
  void _checkIncomingRequests() {
    final appState = context.watch<AppState>();
    final server = appState.httpServerService;

    // 1. 检查是否有配对请求
    if (server.currentPendingPair != null && !_isPairingDialogShowing) {
      _isPairingDialogShowing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPairingRequestDialog(server.currentPendingPair!, server);
      });
    }

    // 2. 检查是否有接收请求
    if (server.currentPendingTransfer != null && !_isTransferDialogShowing) {
      _isTransferDialogShowing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showTransferRequestDialog(server.currentPendingTransfer!, server);
      });
    }
  }

  /// 弹出配对确认弹窗
  void _showPairingRequestDialog(PendingPairRequest request, HttpServerService server) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.security, color: Colors.orange),
              SizedBox(width: 8),
              Text('收到设备配对申请'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('设备名: ${request.deviceName}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('设备指纹: ${request.fingerprint}'),
              const SizedBox(height: 16),
              const Text('请核对双方屏幕上的 6 位安全码是否一致:'),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    request.pin,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _isPairingDialogShowing = false;
                server.resolvePairing(false);
                Navigator.pop(ctx);
              },
              child: const Text('拒绝', style: TextStyle(color: Colors.red)),
            ),
            FilledButton(
              onPressed: () {
                _isPairingDialogShowing = false;
                server.resolvePairing(true);
                Navigator.pop(ctx);
              },
              child: const Text('核对一致，允许配对'),
            ),
          ],
        );
      },
    );
  }

  /// 弹出文件接收确认弹窗
  void _showTransferRequestDialog(PendingTransferRequest request, HttpServerService server) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.download, color: AppTheme.primaryBlue),
              SizedBox(width: 8),
              Text('收到文件传输请求'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('发送方: ${request.deviceName}'),
              const SizedBox(height: 8),
              Text('文件名: ${request.fileName}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('大小: ${_formatSize(request.totalBytes)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _isTransferDialogShowing = false;
                server.resolveTransfer(false);
                Navigator.pop(ctx);
              },
              child: const Text('拒绝', style: TextStyle(color: Colors.red)),
            ),
            FilledButton(
              onPressed: () {
                _isTransferDialogShowing = false;
                server.resolveTransfer(true);
                Navigator.pop(ctx);
              },
              child: const Text('允许接收'),
            ),
          ],
        );
      },
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 720;

        if (isDesktop) {
          // 宽屏模式: 桌面侧边栏布局
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) => setState(() => _currentIndex = index),
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset('assets/logo.png', width: 42, height: 42),
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.radar_outlined),
                      selectedIcon: Icon(Icons.radar),
                      label: Text('雷达互联'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.swap_vert_outlined),
                      selectedIcon: Icon(Icons.swap_vert),
                      label: Text('传输中心'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.verified_user_outlined),
                      selectedIcon: Icon(Icons.verified_user),
                      label: Text('信任管理'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('系统设置'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: _views[_currentIndex],
                ),
              ],
            ),
          );
        } else {
          // 移动端模式: 底部导航栏
          return Scaffold(
            body: _views[_currentIndex],
            bottomNavigationBar: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) => setState(() => _currentIndex = index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.radar_outlined),
                  selectedIcon: Icon(Icons.radar),
                  label: '雷达互联',
                ),
                NavigationDestination(
                  icon: Icon(Icons.swap_vert_outlined),
                  selectedIcon: Icon(Icons.swap_vert),
                  label: '传输中心',
                ),
                NavigationDestination(
                  icon: Icon(Icons.verified_user_outlined),
                  selectedIcon: Icon(Icons.verified_user),
                  label: '信任管理',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: '系统设置',
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
