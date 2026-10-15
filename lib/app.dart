import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/home_screen.dart';
import 'state/timer_controller.dart';
import 'theme/app_theme.dart';

/// 应用根组件：主题 + 全局背景 + 生命周期接线。
class SetBeatApp extends ConsumerStatefulWidget {
  const SetBeatApp({super.key});

  @override
  ConsumerState<SetBeatApp> createState() => _SetBeatAppState();
}

class _SetBeatAppState extends ConsumerState<SetBeatApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      // 退到后台/被遮挡时保存现场。
      // 计时本身不需要任何补偿——引擎用绝对时间记账，回前台第一帧自动补算。
      // 这里保存的意义是：万一进程在后台被系统杀掉，下次启动还能恢复。
      onHide: () {
        ref.read(timerControllerProvider.notifier).saveForBackground();
      },
    );
    // 恢复弹窗的入口在 HomeScreen —— 这里的 context 在 MaterialApp 之上，
    // 拿不到 Navigator / ScaffoldMessenger，showDialog 会直接抛异常
    // （真机上表现为「恢复弹窗从不出现，像被重置了一样」）。
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SetBeat',
        debugShowCheckedModeBanner: false,
        theme: buildSetBeatTheme(),
        // builder 包住 Navigator：所有路由（含计时页、弹窗）都坐在同一块
        // 深色背景上。此前只包了首页，推入计时页后透出白底 —— 已被模拟测试抓到。
        builder: (BuildContext context, Widget? child) =>
            SetBeatBackground(child: child ?? const SizedBox.shrink()),
        home: const HomeScreen(),
      );
}

/// 全局背景：深海军蓝 + 橙 / 青双色氛围渐变。
/// 与原版 `style.css` 的 body 背景逐层对应。
class SetBeatBackground extends StatelessWidget {
  const SetBeatBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        // 第三层（最底）：纯色底 var(--bg-1)。CSS 的 background 列表里它写在最后，
        // 漏掉它就会透出下层白色 —— 已在 Web 模拟测试中实际抓到过。
        decoration: const BoxDecoration(color: SetBeatColors.bg1),
        child: DecoratedBox(
          // radial-gradient(120% 60% at 50% -10%, rgba(255,107,53,.10), transparent 60%)
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -1.2),
              radius: 1.5,
              colors: <Color>[Color(0x1AFF6B35), Color(0x00FF6B35)],
              stops: <double>[0, 0.6],
            ),
          ),
          child: DecoratedBox(
            // radial-gradient(90% 50% at 100% 100%, rgba(78,205,196,.05), transparent 55%)
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(1, 1),
                radius: 1.2,
                colors: <Color>[Color(0x0D4ECDC4), Color(0x004ECDC4)],
                stops: <double>[0, 0.55],
              ),
            ),
            child: child,
          ),
        ),
      );
}
