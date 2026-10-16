import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/foreground_timer_service.dart';
import 'state/services.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 前台服务配置。同步、幂等、不碰平台通道，放在这里最合适：
  // 必须在任何 startService 之前完成，否则插件抛 ServiceNotInitializedException。
  // 它只是往插件里塞了几个静态配置对象，不会有启动开销。
  ForegroundTimerService.configure();

  // 锁竖屏 + 状态栏样式。不 await：这是 main() 里唯一的另一处平台调用，
  // 保持「runApp 之前零阻塞」的原则 —— 就算它失败也只是少了竖屏锁定。
  unawaited(SystemChrome.setPreferredOrientations(
    <DeviceOrientation>[DeviceOrientation.portraitUp],
  ));
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: SetBeatColors.bg1,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // 首帧立刻上屏。服务初始化放后台并行跑——
  // 此前在这里 await 整条初始化链，任何一个平台通道调用挂死
  // 都会让 App 永远停在系统启动屏（真机上已实际踩过）。
  final ProviderContainer container = ProviderContainer();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SetBeatApp(),
    ),
  );
  unawaited(container.read(appBootstrapProvider.future));
}
