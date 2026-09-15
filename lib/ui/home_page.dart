import 'dart:async';
import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device_info.dart';
import '../models/transfer_event.dart';
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
  bool _isWindowDragHovered = false;

  StreamSubscription<TransferEvent>? _eventSub;

  final List<Widget> _views = const [
    RadarView(),
    TransferView(),
    TrustView(),
    SettingsView(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      _eventSub = appState.transferEvents.listen(_handleTransferLifecycleEvent);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkIncomingRequests();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  /// 全局传输事件监听与 Toast/SnackBar 反馈
  void _handleTransferLifecycleEvent(TransferEvent event) {
    if (!mounted) return;

    switch (event.type) {
      case TransferEventType.started:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.primaryBlue,
            duration: const Duration(seconds: 2),
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    event.message ?? '开始文件传输',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        );
        break;

      case TransferEventType.completed:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.accentGreen,
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    event.message ?? '传输完成！',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            action: event.localPath != null
                ? SnackBarAction(
                    label: '打开文件',
                    textColor: Colors.white,
                    onPressed: () => _openPath(event.localPath!),
                  )
                : null,
          ),
        );
        break;

      case TransferEventType.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.alertRed,
            duration: const Duration(seconds: 5),
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    event.message ?? '传输失败',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
        break;

      case TransferEventType.rejected:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.warningOrange,
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Icons.block, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    event.message ?? '对方拒绝了传输请求',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
        break;
    }
  }

  /// 快捷打开文件
  void _openPath(String path) {
    if (Platform.isLinux) {
      Process.run('xdg-open', [path]);
    } else if (Platform.isWindows) {
      Process.run('explorer.exe', [path]);
    }
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.security, color: AppTheme.warningOrange),
              SizedBox(width: 10),
              Text('收到设备配对申请'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('设备名: ${request.deviceName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text('安全指纹: ${request.fingerprint}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 18),
              const Text('请核对双方屏幕上的 6 位安全配对码:'),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
                ),
                child: Center(
                  child: Text(
                    request.pin,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
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
              child: const Text('拒绝', style: TextStyle(color: AppTheme.alertRed)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.download_rounded, color: AppTheme.primaryBlue),
              SizedBox(width: 10),
              Text('收到文件传输请求'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('发送方: ${request.deviceName}', style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.fileName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '大小: ${_formatSize(request.totalBytes)}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _isTransferDialogShowing = false;
                server.resolveTransfer(false);
                Navigator.pop(ctx);
              },
              child: const Text('拒绝', style: TextStyle(color: AppTheme.alertRed)),
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

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec <= 0) return '0 KB/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  /// 全局窗口拖放处理
  Future<void> _handleWindowFilesDrop(List<DropItem> items, AppState appState) async {
    final files = <File>[];
    for (final item in items) {
      final type = FileSystemEntity.typeSync(item.path);
      if (type == FileSystemEntityType.file) {
        files.add(File(item.path));
      } else if (type == FileSystemEntityType.directory) {
        final dir = Directory(item.path);
        try {
          for (final entity in dir.listSync(recursive: true)) {
            if (entity is File) files.add(entity);
          }
        } catch (_) {}
      }
    }
    if (files.isEmpty) return;

    final trusted = appState.trustedOnlineDevices;
    if (trusted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.warningOrange,
          content: Text('未发现已信任的在线设备，请先在雷达中完成配对'),
        ),
      );
      return;
    }

    if (trusted.length == 1) {
      final target = trusted.first;
      for (final f in files) {
        appState.sendFileToDevice(target, f);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('正在向 ${target.name} 发送 ${files.length} 个文件...'),
        ),
      );
    } else {
      _showQuickDevicePicker(context, files, trusted, appState);
    }
  }

  void _showQuickDevicePicker(
    BuildContext context,
    List<File> files,
    List<DeviceInfo> devices,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: Text(
                    '快速投送 (${files.length} 个文件)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const Divider(),
                ...devices.map(
                  (dev) => ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEFF6FF),
                      child: Icon(Icons.devices, color: AppTheme.primaryBlue),
                    ),
                    title: Text(dev.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('IP: ${dev.ip}'),
                    trailing: const Icon(Icons.send_rounded, color: AppTheme.primaryBlue),
                    onTap: () {
                      Navigator.pop(ctx);
                      for (final f in files) {
                        appState.sendFileToDevice(dev, f);
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text('正在向 ${dev.name} 发送 ${files.length} 个文件...'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final activeTransfers = appState.activeTransfers;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 720;

        Widget contentWidget;
        if (isDesktop) {
          contentWidget = Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) => setState(() => _currentIndex = index),
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset('assets/logo.png', width: 44, height: 44),
                    ),
                  ),
                  destinations: [
                    const NavigationRailDestination(
                      icon: Icon(Icons.radar_outlined),
                      selectedIcon: Icon(Icons.radar),
                      label: Text('雷达互联'),
                    ),
                    NavigationRailDestination(
                      icon: activeTransfers.isNotEmpty
                          ? Badge.count(
                              count: activeTransfers.length,
                              backgroundColor: AppTheme.primaryBlue,
                              child: const Icon(Icons.swap_vert_outlined),
                            )
                          : const Icon(Icons.swap_vert_outlined),
                      selectedIcon: const Icon(Icons.swap_vert),
                      label: const Text('传输中心'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.verified_user_outlined),
                      selectedIcon: Icon(Icons.verified_user),
                      label: Text('信任管理'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('系统设置'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: _views[_currentIndex]),
              ],
            ),
          );
        } else {
          contentWidget = Scaffold(
            body: _views[_currentIndex],
            bottomNavigationBar: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) => setState(() => _currentIndex = index),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.radar_outlined),
                  selectedIcon: Icon(Icons.radar),
                  label: '雷达互联',
                ),
                NavigationDestination(
                  icon: activeTransfers.isNotEmpty
                      ? Badge.count(
                          count: activeTransfers.length,
                          backgroundColor: AppTheme.primaryBlue,
                          child: const Icon(Icons.swap_vert_outlined),
                        )
                      : const Icon(Icons.swap_vert_outlined),
                  selectedIcon: const Icon(Icons.swap_vert),
                  label: '传输中心',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.verified_user_outlined),
                  selectedIcon: Icon(Icons.verified_user),
                  label: '信任管理',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: '系统设置',
                ),
              ],
            ),
          );
        }

        // 全局拖拽容器与浮动传输胶囊组合
        return DropTarget(
          onDragEntered: (_) => setState(() => _isWindowDragHovered = true),
          onDragExited: (_) => setState(() => _isWindowDragHovered = false),
          onDragDone: (details) async {
            setState(() => _isWindowDragHovered = false);
            await _handleWindowFilesDrop(details.files, appState);
          },
          child: Stack(
            children: [
              contentWidget,

              // 1. 全局文件拖入遮罩 (高科技全屏提示)
              if (_isWindowDragHovered)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.6),
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.all(40),
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppTheme.primaryBlue, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.4),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.cloud_upload_rounded, size: 64, color: AppTheme.primaryBlue),
                            SizedBox(height: 16),
                            Text(
                              '松开鼠标即可投送文件',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '可直接向当前已配对的局域网设备发起安全传输',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // 2. 全局悬浮微型传输进度胶囊 (当用户处于非传输中心页面且有活跃传输时呈现)
              if (activeTransfers.isNotEmpty && _currentIndex != 1)
                Positioned(
                  bottom: isDesktop ? 24 : 88,
                  right: 24,
                  child: Material(
                    elevation: 6,
                    shadowColor: AppTheme.primaryBlue.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(30),
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: () => setState(() => _currentIndex = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.5), width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${activeTransfers.length} 个传输中 (${_formatSpeed(appState.totalTransferSpeed)})',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.primaryBlue),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
