/// 帧驱动源的抽象。
///
/// 引擎本身不依赖 Flutter —— 帧驱动由外部注入，
/// 生产环境用 vsync 的 [TickerTickSource]，测试用 [ManualTickSource]。
abstract class TickSource {
  void start(void Function() onTick);

  void stop();
}

/// 什么都不做的实现，用作引擎的默认值。
class NoopTickSource implements TickSource {
  const NoopTickSource();

  @override
  void start(void Function() onTick) {}

  @override
  void stop() {}
}

/// 手动驱动的帧源。测试里推进假时钟后调用 [pump] 即可模拟一帧。
class ManualTickSource implements TickSource {
  void Function()? _callback;

  bool get isActive => _callback != null;

  @override
  void start(void Function() onTick) {
    _callback = onTick;
  }

  @override
  void stop() {
    _callback = null;
  }

  /// 手动触发一帧
  void pump() => _callback?.call();

  /// 连续触发 [times] 帧（帧间隔由假时钟的推进决定）
  void pumpTimes(int times) {
    for (int i = 0; i < times; i++) {
      _callback?.call();
    }
  }
}
