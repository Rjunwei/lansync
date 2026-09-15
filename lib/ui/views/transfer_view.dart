import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('传输中心', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: transfers.isEmpty
          ? _buildEmptyState(context)
          : ListView.separated(
              padding: const EdgeInsets.all(16.0),
              itemCount: transfers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = transfers[index];
                return _buildTransferCard(context, item);
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.swap_horizontal_circle_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('暂无传输记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            '在设备雷达中选择已信任设备，即可发起文件互传',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferCard(BuildContext context, TransferItem item) {
    final isSending = item.direction == TransferDirection.send;
    final isComplete = item.status == TransferStatus.completed;
    final isFailed = item.status == TransferStatus.failed;

    Color statusColor;
    if (isComplete) {
      statusColor = AppTheme.accentGreen;
    } else if (isFailed) {
      statusColor = Colors.red;
    } else {
      statusColor = AppTheme.primaryBlue;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  child: Icon(
                    isSending ? Icons.arrow_upward : Icons.arrow_downward,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
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
                      const SizedBox(height: 2),
                      Text(
                        '${isSending ? "发往" : "来自"}: ${item.peerDeviceName} • ${_formatFileSize(item.totalBytes)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(item),
              ],
            ),

            if (item.status == TransferStatus.transferring) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: item.progress,
                backgroundColor: Colors.grey.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation(AppTheme.primaryBlue),
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(item.progress * 100).toStringAsFixed(1)}% (${_formatFileSize(item.transferredBytes)} / ${_formatFileSize(item.totalBytes)})',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Text(
                    _formatSpeed(item.speedBytesPerSec),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                  ),
                ],
              ),
            ],

            if (item.textContent != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.textContent!,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],

            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('yyyy-MM-dd HH:mm:ss').format(item.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                Row(
                  children: [
                    if (item.textContent != null)
                      TextButton.icon(
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('复制文本'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: item.textContent!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已复制到剪贴板')),
                          );
                        },
                      ),
                    if (item.localPath != null && isComplete)
                      TextButton.icon(
                        icon: const Icon(Icons.folder_open, size: 14),
                        label: const Text('打开文件位置'),
                        onPressed: () => _openFileLocation(context, item.localPath!),
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
        text = '完成';
        color = AppTheme.accentGreen;
        break;
      case TransferStatus.transferring:
        text = '传输中';
        color = AppTheme.primaryBlue;
        break;
      case TransferStatus.failed:
        text = '失败';
        color = Colors.red;
        break;
      case TransferStatus.canceled:
        text = '已取消';
        color = Colors.grey;
        break;
      case TransferStatus.pending:
        text = '等待中';
        color = Colors.orange;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _openFileLocation(BuildContext context, String path) {
    final file = File(path);
    final dir = file.parent.path;
    if (Platform.isLinux) {
      Process.run('xdg-open', [dir]);
    } else if (Platform.isWindows) {
      Process.run('explorer.exe', ['/select,', path]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存路径: $path')),
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
