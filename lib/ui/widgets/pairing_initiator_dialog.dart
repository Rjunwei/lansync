import 'package:flutter/material.dart';
import '../../models/device_info.dart';
import '../../providers/app_state.dart';
import '../theme.dart';

/// 发起方 6 位配对码展示与等待核验弹窗
class PairingInitiatorDialog extends StatefulWidget {
  final DeviceInfo dev;
  final String pin;
  final AppState appState;

  const PairingInitiatorDialog({
    super.key,
    required this.dev,
    required this.pin,
    required this.appState,
  });

  /// 快捷弹出方法
  static Future<void> show(BuildContext context, DeviceInfo dev, AppState appState) async {
    final pin = appState.securityService.generatePairingPin();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PairingInitiatorDialog(
        dev: dev,
        pin: pin,
        appState: appState,
      ),
    );
  }

  @override
  State<PairingInitiatorDialog> createState() => _PairingInitiatorDialogState();
}

class _PairingInitiatorDialogState extends State<PairingInitiatorDialog> {
  bool _isLoading = true;
  bool? _isSuccess;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startPairing();
  }

  Future<void> _startPairing() async {
    final success = await widget.appState.pairWithDevice(widget.dev, pin: widget.pin);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isSuccess = success;
      if (!success) {
        _errorMessage = '对方拒绝了配对申请，或请求超时';
      }
    });

    if (success) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(
            _isSuccess == true
                ? Icons.check_circle
                : (_isSuccess == false ? Icons.error_outline : Icons.security),
            color: _isSuccess == true
                ? AppTheme.accentGreen
                : (_isSuccess == false ? AppTheme.alertRed : AppTheme.primaryBlue),
          ),
          const SizedBox(width: 10),
          Text(_isSuccess == true ? '配对成功' : '安全配对申请'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('目标设备: ${widget.dev.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text('设备指纹: ${widget.dev.fingerprint}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 16),
          const Text('请核对双方屏幕上的 6 位安全配对码是否一致:'),
          const SizedBox(height: 10),
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
                widget.pin,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryBlue),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '请在对方屏幕核对一致后点击允许...',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            )
          else if (_isSuccess == true)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.verified, color: AppTheme.accentGreen, size: 18),
                SizedBox(width: 8),
                Text('配对成功！已加入受信任白名单', style: TextStyle(fontSize: 13, color: AppTheme.accentGreen, fontWeight: FontWeight.bold)),
              ],
            )
          else
            Text(
              _errorMessage ?? '配对失败',
              style: const TextStyle(fontSize: 13, color: AppTheme.alertRed),
            ),
        ],
      ),
      actions: [
        if (_isLoading)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消申请'),
          )
        else
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('完成'),
          ),
      ],
    );
  }
}
