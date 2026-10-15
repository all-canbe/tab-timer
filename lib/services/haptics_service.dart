import 'package:vibration/vibration.dart';

/// 震动服务，语义与原版 `src/composables/useVibration.ts` 一致：
///   切换   [150, 80, 150]
///   结束   [200, 100, 200, 100, 200]
///   倒数秒 不震动（运动时手臂频繁震动会不适，原版特意如此设计）
///
/// 原版的隐患：`navigator.vibrate` 依赖 Android WebView 的 VIBRATE 权限，
/// 而原版 manifest 根本没声明——所以震动在真机上大概率一直是哑的。
/// Flutter 版走原生 VibrationEffect，权限已显式补上。
class HapticsService {
  bool enabled = true;

  bool _supported = false;
  bool get isSupported => _supported;

  Future<void> init() async {
    try {
      _supported = await Vibration.hasVibrator();
    } catch (_) {
      // Web 目标 / 无震动马达设备：静默降级
      _supported = false;
    }
  }

  /// 阶段切换：两次短震
  Future<void> playTransition() => _vibrate(const <int>[150, 80, 150]);

  /// 训练完成：三次短震
  Future<void> playFinish() => _vibrate(const <int>[200, 100, 200, 100, 200]);

  /// 立即停止当前震动（重置 / 离开计时页时收尾）
  Future<void> cancel() async {
    try {
      await Vibration.cancel();
    } catch (_) {}
  }

  Future<void> _vibrate(List<int> pattern) async {
    if (!enabled || !_supported) return;
    try {
      await Vibration.vibrate(pattern: pattern);
    } catch (_) {
      // 震动失败绝不能打断计时流程
    }
  }
}
