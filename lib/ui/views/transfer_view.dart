import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../models/transfer_item.dart';
import '../../providers/app_state.dart';
import '../theme.dart';

class TransferView extends StatelessWidget {
  const TransferView({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final transfers = appState.allTransfers;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('传输中心', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (transfers.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.cleaning_services_outlined, size: 18),
              label: const Text('清理历史'),
              onPressed: () {
                appState.clearTransferHistory();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    behavior: SnackBarBehavior.floating,
                    content: Text('已清除历史传输记录'),
                  ),
                );
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: transfers.isEmpty
          ? _buildEmptyState(context, isDark)
          : ListView.separated(
              padding: const EdgeInsets.all(16.0),
              itemCount: transfers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = transfers[index];
                return _buildTransferCard(context, item, isDark, appState);
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
            ),
            child: const Icon(
              Icons.swap_horizontal_circle_outlined,
              size: 48,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '暂无传输记录',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '可直接将文件拖拽入窗口，或在设备雷达中选择设备进行投送',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferCard(
    BuildContext context,
    TransferItem item,
    bool isDark,
    AppState appState,
  ) {
    final isSending = item.direction == TransferDirection.send;
    final isComplete = item.status == TransferStatus.completed;
    final isFailed = item.status == TransferStatus.failed;
    final isTransferring = item.status == TransferStatus.transferring;

    Color statusColor;
    if (isComplete) {
      statusColor = AppTheme.accentGreen;
    } else if (isFailed) {
      statusColor = AppTheme.alertRed;
    } else {
      statusColor = AppTheme.primaryBlue;
    }

    final fileIcon = _getFileIcon(item.fileName, item.contentType);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：图标、文件名、目标、状态徽章
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(fileIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            isSending ? Icons.upload : Icons.download,
                            size: 13,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${isSending ? "发往" : "来自"}: ${item.peerDeviceName} • ${_formatFileSize(item.totalBytes)}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(item),
              ],
            ),

            // 进度条与速度
            if (isTransferring) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: item.progress > 0 ? item.progress : null,
                  minHeight: 6,
                  backgroundColor: Colors.grey.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation(AppTheme.primaryBlue),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(item.progress * 100).toStringAsFixed(1)}% (${_formatFileSize(item.transferredBytes)} / ${_formatFileSize(item.totalBytes)})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatSpeed(item.speedBytesPerSec),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // 错误详情提示框
            if (isFailed && item.error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.alertRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.alertRed.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.alertRed, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '失败原因: ${item.error}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.alertRed),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 文本内容展示区
            if (item.textContent != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: SelectableText(
                  item.textContent!,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // 底部元信息与操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MM-dd HH:mm:ss').format(item.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    if (item.textContent != null)
                      TextButton.icon(
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('复制文本'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: item.textContent!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              behavior: SnackBarBehavior.floating,
                              content: Text('已复制到系统剪贴板'),
                            ),
                          );
                        },
                      ),
                    if (item.localPath != null && isComplete) ...[
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                        icon: const Icon(Icons.open_in_new, size: 14),
                        label: const Text('打开文件'),
                        onPressed: () => _openFile(context, item.localPath!),
                      ),
                      IconButton(
                        tooltip: '打开所在文件夹',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.folder_open, size: 18),
                        onPressed: () => _openDirectory(context, item.localPath!),
                      ),
                    ],
                    if (isFailed && isSending && item.localPath != null)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: AppTheme.primaryBlue,
                        ),
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('重新发送'),
                        onPressed: () {
                          final target = appState.onlineDevices.cast<dynamic>().firstWhere(
                                (d) => d.id == item.peerDeviceId,
                                orElse: () => null,
                              );
                          if (target != null) {
                            appState.sendFileToDevice(target, File(item.localPath!));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                behavior: SnackBarBehavior.floating,
                                content: Text('目标设备目前不在线，无法重试'),
                              ),
                            );
                          }
                        },
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(TransferItem item) {
    String text;
    Color color;
    switch (item.status) {
      case TransferStatus.completed:
        text = '已完成';
        color = AppTheme.accentGreen;
        break;
      case TransferStatus.transferring:
        text = '传输中';
        color = AppTheme.primaryBlue;
        break;
      case TransferStatus.failed:
        text = '传输失败';
        color = AppTheme.alertRed;
        break;
      case TransferStatus.canceled:
        text = '已取消';
        color = Colors.grey;
        break;
      case TransferStatus.pending:
        text = '等待确认';
        color = AppTheme.warningOrange;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// 根据扩展名智能匹配现代图标
  IconData _getFileIcon(String fileName, TransferContentType type) {
    if (type == TransferContentType.text) return Icons.text_snippet_outlined;
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.webp':
      case '.bmp':
      case '.svg':
        return Icons.image_outlined;
      case '.mp4':
      case '.mkv':
      case '.avi':
      case '.mov':
      case '.wmv':
      case '.flv':
        return Icons.movie_outlined;
      case '.mp3':
      case '.wav':
      case '.flac':
      case '.aac':
      case '.ogg':
        return Icons.music_note_outlined;
      case '.zip':
      case '.rar':
      case '.7z':
      case '.tar':
      case '.gz':
        return Icons.folder_zip_outlined;
      case '.pdf':
        return Icons.picture_as_pdf_outlined;
      case '.doc':
      case '.docx':
      case '.xls':
      case '.xlsx':
      case '.ppt':
      case '.pptx':
      case '.txt':
      case '.md':
        return Icons.description_outlined;
      case '.apk':
        return Icons.android_outlined;
      case '.exe':
      case '.msi':
        return Icons.desktop_windows_outlined;
      case '.deb':
      case '.rpm':
        return Icons.terminal_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  /// 直接打开文件
  void _openFile(BuildContext context, String path) {
    final file = File(path);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(behavior: SnackBarBehavior.floating, content: Text('文件不存在或已被移动')),
      );
      return;
    }

    if (Platform.isLinux) {
      Process.run('xdg-open', [path]);
    } else if (Platform.isWindows) {
      Process.run('explorer.exe', [path]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text('保存路径: $path')),
      );
    }
  }

  /// 打开所在文件夹
  void _openDirectory(BuildContext context, String path) {
    final file = File(path);
    final dir = file.parent.path;
    if (Platform.isLinux) {
      Process.run('xdg-open', [dir]);
    } else if (Platform.isWindows) {
      Process.run('explorer.exe', ['/select,', path]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text('保存目录: $dir')),
      );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec <= 0) return '0 KB/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
}
