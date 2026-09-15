import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/device_info.dart';
import '../../providers/app_state.dart';
import '../theme.dart';

/// 扫码配对界面 (APK / 移动端专用)
class QrScannerView extends StatefulWidget {
  final AppState appState;

  const QrScannerView({super.key, required this.appState});

  static Future<bool?> open(BuildContext context, AppState appState) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QrScannerView(appState: appState),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView>
    with SingleTickerProviderStateMixin {
  late MobileScannerController _controller;
  late AnimationController _animController;
  late Animation<double> _scanAnimation;
  bool _isProcessing = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null || rawValue.isEmpty) continue;

      try {
        final data = jsonDecode(rawValue) as Map<String, dynamic>;
        if (data['action'] == 'pair' && data['token'] != null && data['ip'] != null) {
          setState(() => _isProcessing = true);

          final targetDev = DeviceInfo(
            id: data['id'] as String? ?? 'device_${DateTime.now().millisecondsSinceEpoch}',
            name: data['name'] as String? ?? '局域网设备',
            platform: DevicePlatform.unknown,
            ip: data['ip'] as String,
            port: data['port'] as int? ?? 53317,
            fingerprint: data['fp'] as String? ?? '',
            lastSeen: DateTime.now(),
          );

          final token = data['token'] as String;

          final success = await widget.appState.pairWithDevice(
            targetDev,
            token: token,
          );

          if (!mounted) return;

          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppTheme.accentGreen,
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(child: Text('已成功与【${targetDev.name}】配对并加入信任列表！')),
                  ],
                ),
              ),
            );
            Navigator.pop(context, true);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppTheme.alertRed,
                content: Text('扫码配对失败：Token 已过期或对端拒绝'),
              ),
            );
            setState(() => _isProcessing = false);
          }
          return;
        }
      } catch (_) {
        // 非 LanSync 配对二维码，继续扫描
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanSize = size.width * 0.7;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. 相机画面
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
          ),

          // 2. 扫码框遮罩与动画
          Center(
            child: Container(
              width: scanSize,
              height: scanSize,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryBlue, width: 2.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    // 扫描激光线
                    AnimatedBuilder(
                      animation: _scanAnimation,
                      builder: (context, child) {
                        return Positioned(
                          top: _scanAnimation.value * (scanSize - 10),
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryBlue.withValues(alpha: 0.1),
                                  AppTheme.secondaryCyan,
                                  AppTheme.primaryBlue.withValues(alpha: 0.1),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.secondaryCyan.withValues(alpha: 0.8),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. 顶部导航与操作栏
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    '扫描对方二维码',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _isTorchOn ? Icons.flash_on : Icons.flash_off,
                          color: _isTorchOn ? Colors.yellow : Colors.white,
                        ),
                        onPressed: () async {
                          await _controller.toggleTorch();
                          setState(() => _isTorchOn = !_isTorchOn);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.flip_camera_android, color: Colors.white),
                        onPressed: () => _controller.switchCamera(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 4. 底部提示
          Positioned(
            bottom: 80,
            left: 20,
            right: 20,
            child: Column(
              children: [
                if (_isProcessing)
                  const CircularProgressIndicator(color: AppTheme.primaryBlue)
                else ...[
                  const Icon(Icons.qr_code_scanner, color: Colors.white70, size: 32),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '对准另一台电脑或手机上的【配对二维码】即可自动互信',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
