/// 传输方向
enum TransferDirection {
  send,
  receive,
}

/// 传输状态
enum TransferStatus {
  pending,
  transferring,
  completed,
  failed,
  canceled,
}

/// 传输内容类别
enum TransferContentType {
  file,
  directory,
  text,
}

/// 传输任务实体
class TransferItem {
  final String id;
  final String peerDeviceId;
  final String peerDeviceName;
  final TransferDirection direction;
  final TransferContentType contentType;
  final String fileName;
  final int totalBytes;
  int transferredBytes;
  double speedBytesPerSec;
  TransferStatus status;
  String? localPath;
  String? textContent; // 如果是纯文本/URL分享
  String? error;
  final DateTime createdAt;

  TransferItem({
    required this.id,
    required this.peerDeviceId,
    required this.peerDeviceName,
    required this.direction,
    required this.contentType,
    required this.fileName,
    required this.totalBytes,
    this.transferredBytes = 0,
    this.speedBytesPerSec = 0.0,
    this.status = TransferStatus.pending,
    this.localPath,
    this.textContent,
    this.error,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get progress {
    if (totalBytes <= 0) return 0.0;
    return (transferredBytes / totalBytes).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'peerDeviceId': peerDeviceId,
        'peerDeviceName': peerDeviceName,
        'direction': direction.name,
        'contentType': contentType.name,
        'fileName': fileName,
        'totalBytes': totalBytes,
        'transferredBytes': transferredBytes,
        'status': status.name,
        'localPath': localPath,
        'textContent': textContent,
        'error': error,
        'createdAt': createdAt.toIso8601String(),
      };
}
