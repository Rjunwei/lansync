import 'transfer_item.dart';

enum TransferEventType {
  started,
  completed,
  failed,
  rejected,
}

class TransferEvent {
  final TransferEventType type;
  final TransferItem item;
  final String? message;
  final String? localPath;

  const TransferEvent({
    required this.type,
    required this.item,
    this.message,
    this.localPath,
  });
}
