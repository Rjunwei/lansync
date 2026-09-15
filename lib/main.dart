import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appState = AppState();
  // 异步初始化，无需等待网络接口和端口绑定即可瞬间完成窗口绘制
  unawaited(appState.initialize());

  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const LanSyncApp(),
    ),
  );
}

class LanSyncApp extends StatelessWidget {
  const LanSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LanSync 安全互传',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // 跟随系统深浅模式
      home: const HomePage(),
    );
  }
}
