import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/device_info.dart';
import '../../providers/app_state.dart';
import '../theme.dart';
import '../widgets/pairing_initiator_dialog.dart';

class RadarView extends StatefulWidget {
  const RadarView({super.key});

  @override
  State<RadarView> createState() => _RadarViewState();
}

class _RadarViewState extends State<RadarView> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  String? _hoveredDeviceId;
  bool _isBottomDropZoneHovered = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeOutQuad,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('设备雷达与互传', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            // 雷达活跃状态微标
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: appState.isGhostMode
                    ? Colors.grey.withValues(alpha: 0.15)
                    : AppTheme.accentGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: appState.isGhostMode ? Colors.grey : AppTheme.accentGreen,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    appState.isGhostMode ? '隐身模式' : '持续雷达探测中',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: appState.isGhostMode ? Colors.grey : AppTheme.accentGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '重新探测局域网',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              appState.refreshDiscovery();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text('已发送局域网广播探测帧...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
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

            // 2. 局域网设备雷达头部
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Container(
                              width: 24 + (_pulseAnimation.value * 12),
                              height: 24 + (_pulseAnimation.value * 12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.primaryBlue.withValues(
                                  alpha: (1 - _pulseAnimation.value) * 0.35,
                                ),
                              ),
                            );
                          },
                        ),
                        const Icon(Icons.radar, color: AppTheme.primaryBlue, size: 22),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '在线设备 (${appState.onlineDevices.length})',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  '支持直接拖放文件到设备卡片',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (appState.onlineDevices.isEmpty)
              _buildEmptyDeviceState(context, isDark)
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 420,
                  mainAxisExtent: 156,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: appState.onlineDevices.length,
                itemBuilder: (context, index) {
                  final dev = appState.onlineDevices[index];
                  final isTrusted = appState.isDeviceTrusted(dev.id);
                  return _buildDeviceCard(context, dev, isTrusted, appState, isDark);
                },
              ),

            const SizedBox(height: 28),

            // 3. 底部快速拖拽/点击投送区
            _buildInteractiveDropZone(context, appState, isDark),
          ],
        ),
      ),
    );
  }

  /// 本机设备卡片
  Widget _buildMyDeviceCard(BuildContext context, AppState appState, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.devices, color: AppTheme.primaryBlue, size: 26),
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
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '本机',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.accentGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
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
                appState.isGhostMode ? '隐身中' : '可见',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 无设备扫描态展示（带脉冲动画）
  Widget _buildEmptyDeviceState(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 70 + (_pulseAnimation.value * 40),
                    height: 70 + (_pulseAnimation.value * 40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryBlue.withValues(
                        alpha: (1 - _pulseAnimation.value) * 0.2,
                      ),
                    ),
                  ),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    ),
                    child: const Icon(Icons.wifi_tethering, size: 36, color: AppTheme.primaryBlue),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            '正在扫描局域网中的设备...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '请确保其他设备连接在同一 Wi-Fi 或路由器局域网下，且已打开 LanSync 客户端',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  /// 单个设备卡片 (支持拖拽投送到此卡片)
  Widget _buildDeviceCard(
    BuildContext context,
    DeviceInfo dev,
    bool isTrusted,
    AppState appState,
    bool isDark,
  ) {
    final isHovered = _hoveredDeviceId == dev.id;

    IconData platformIcon;
    Color platformColor;
    switch (dev.platform) {
      case DevicePlatform.windows:
        platformIcon = Icons.window;
        platformColor = const Color(0xFF0078D4);
        break;
      case DevicePlatform.linux:
        platformIcon = Icons.terminal;
        platformColor = const Color(0xFFE95420);
        break;
      case DevicePlatform.android:
        platformIcon = Icons.android;
        platformColor = const Color(0xFF3DDC84);
        break;
      default:
        platformIcon = Icons.devices_other;
        platformColor = AppTheme.primaryBlue;
    }

    return DropTarget(
      onDragEntered: (details) {
        setState(() => _hoveredDeviceId = dev.id);
      },
      onDragExited: (details) {
        setState(() {
          if (_hoveredDeviceId == dev.id) _hoveredDeviceId = null;
        });
      },
      onDragDone: (details) async {
        setState(() => _hoveredDeviceId = null);
        if (!isTrusted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppTheme.warningOrange,
              content: Text('${dev.name} 尚未授权配对，请先点击【授权配对】'),
            ),
          );
          return;
        }
        await _handleDropFilesToDevice(details.files, dev, appState);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isHovered
              ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE))
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHovered
                ? AppTheme.primaryBlue
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isHovered ? 2 : 1,
          ),
          boxShadow: isHovered
              ? [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showDeviceActionSheet(context, dev, isTrusted, appState),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 顶部：平台图标、设备名、指纹与授权徽章
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: platformColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(platformIcon, color: platformColor, size: 22),
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
                          const SizedBox(height: 2),
                          Text(
                            '${dev.ip} (${dev.fingerprint})',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    // 状态徽标
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isTrusted
                            ? AppTheme.accentGreen.withValues(alpha: 0.12)
                            : AppTheme.warningOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isTrusted
                              ? AppTheme.accentGreen.withValues(alpha: 0.3)
                              : AppTheme.warningOrange.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        isTrusted ? '已信任' : '未授权',
                        style: TextStyle(
                          fontSize: 11,
                          color: isTrusted ? AppTheme.accentGreen : AppTheme.warningOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                // 底部操作与拖拽提示
                if (isHovered)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.file_download, color: AppTheme.primaryBlue, size: 16),
                          SizedBox(width: 6),
                          Text(
                            '松手即可立即投送到此设备',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '可拖拽文件直接投送',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                      ),
                      if (!isTrusted)
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                          onPressed: () => _triggerPairing(context, dev, appState),
                          child: const Text('授权配对'),
                        )
                      else
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                          icon: const Icon(Icons.send_rounded, size: 14),
                          label: const Text('发送文件'),
                          onPressed: () => _pickAndSendFile(context, dev, appState),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 底部交互式投送区域（点击选文件 或 拖拽落入）
  Widget _buildInteractiveDropZone(BuildContext context, AppState appState, bool isDark) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _isBottomDropZoneHovered = true),
      onDragExited: (_) => setState(() => _isBottomDropZoneHovered = false),
      onDragDone: (details) async {
        setState(() => _isBottomDropZoneHovered = false);
        await _handleGlobalOrDropzoneFiles(details.files, appState);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
        decoration: BoxDecoration(
          color: _isBottomDropZoneHovered
              ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE))
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isBottomDropZoneHovered
                ? AppTheme.primaryBlue
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: _isBottomDropZoneHovered ? 2 : 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleBottomDropZoneClick(context, appState),
          child: Column(
            children: [
              Icon(
                _isBottomDropZoneHovered ? Icons.file_download : Icons.cloud_upload_outlined,
                size: 42,
                color: AppTheme.primaryBlue,
              ),
              const SizedBox(height: 10),
              Text(
                _isBottomDropZoneHovered ? '松开鼠标即可投送文件' : '点击选择文件，或拖拽任意文件到此处',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                '支持任意类型文件与文件夹拖拽传输；仅在已受信任的白名单设备之间互通。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 点击底部投送区
  Future<void> _handleBottomDropZoneClick(BuildContext context, AppState appState) async {
    final trusted = appState.trustedOnlineDevices;
    if (trusted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.warningOrange,
          content: Text('当前没有已授权的在线设备，请先在上方设备列表中点击【授权配对】'),
        ),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null && result.files.isNotEmpty) {
      final files = result.files
          .where((f) => f.path != null)
          .map((f) => File(f.path!))
          .toList();
      if (!context.mounted) return;
      _dispatchFilesToDevices(context, files, appState);
    }
  }

  /// 递归解析拖放的 DropItem（提取所有合法文件）
  List<File> _resolveDroppedFiles(List<DropItem> items) {
    final fileList = <File>[];
    for (final item in items) {
      final type = FileSystemEntity.typeSync(item.path);
      if (type == FileSystemEntityType.file) {
        fileList.add(File(item.path));
      } else if (type == FileSystemEntityType.directory) {
        final dir = Directory(item.path);
        try {
          for (final entity in dir.listSync(recursive: true)) {
            if (entity is File) {
              fileList.add(entity);
            }
          }
        } catch (_) {}
      }
    }
    return fileList;
  }

  /// 拖放至指定设备
  Future<void> _handleDropFilesToDevice(
    List<DropItem> items,
    DeviceInfo target,
    AppState appState,
  ) async {
    final files = _resolveDroppedFiles(items);
    if (files.isEmpty) return;

    for (final f in files) {
      appState.sendFileToDevice(target, f);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('已向 ${target.name} 发送 ${files.length} 个文件'),
      ),
    );
  }

  /// 全局或投送区拖放触发
  Future<void> _handleGlobalOrDropzoneFiles(List<DropItem> items, AppState appState) async {
    final files = _resolveDroppedFiles(items);
    if (files.isEmpty) return;
    _dispatchFilesToDevices(context, files, appState);
  }

  /// 决定将文件投送给哪台受信任设备
  void _dispatchFilesToDevices(BuildContext context, List<File> files, AppState appState) {
    final trusted = appState.trustedOnlineDevices;
    if (trusted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.warningOrange,
          content: Text('未发现已信任的在线设备，请先完成设备配对'),
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
      // 多台受信任设备时，弹出极简选择面板
      _showTargetDevicePicker(context, files, trusted, appState);
    }
  }

  /// 弹出选择目标设备弹窗
  void _showTargetDevicePicker(
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
                    '选择接收设备 (${files.length} 个待投送文件)',
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
                    trailing: const Icon(Icons.chevron_right),
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

  /// 点击设备卡片详情与菜单
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
                        : AppTheme.warningOrange.withValues(alpha: 0.15),
                  ),
                ),
                const Divider(),
                if (isTrusted) ...[
                  ListTile(
                    leading: const Icon(Icons.file_upload_outlined, color: AppTheme.primaryBlue),
                    title: const Text('选取并发送文件'),
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
                    leading: const Icon(Icons.delete_outline, color: AppTheme.alertRed),
                    title: const Text('解除设备授权', style: TextStyle(color: AppTheme.alertRed)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await appState.unpairDevice(dev.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text('已移除对 ${dev.name} 的授权'),
                          ),
                        );
                      }
                    },
                  ),
                ] else ...[
                  ListTile(
                    leading: const Icon(Icons.security, color: AppTheme.warningOrange),
                    title: const Text('向该设备申请配对许可'),
                    subtitle: const Text('需要双方核对屏幕 6 位安全码'),
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

  /// 触发配对申请：本机生成 6 位安全码并弹窗显示，与对端屏幕同时核对
  Future<void> _triggerPairing(
    BuildContext context,
    DeviceInfo dev,
    AppState appState,
  ) async {
    await PairingInitiatorDialog.show(context, dev, appState);
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
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('已添加 ${result.files.length} 个文件到发送队列'),
          ),
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
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text(ok ? '发送成功！' : '发送失败，请检查对端状态'),
                      ),
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
}
