/// 计时引擎的时钟抽象。
///
/// 分两个时间源，用途不同：
///   - [nowMs]  单调递增毫秒计数，用于帧内精度。不受系统时间被修改影响。
///   - [wallMs] 墙钟时间戳（毫秒），用于持久化快照与跨进程恢复。
///
/// 注入时钟是引擎可单测的前提：测试里把 25 分钟的计时瞬间推完，
/// 不需要真的等待。
abstract class EngineClock {
  /// 单调递增的毫秒计数
  int nowMs();

  /// 墙钟时间戳（毫秒）
  int wallMs();
}

/// 生产实现：Stopwatch 提供单调时间，DateTime 提供墙钟时间。
class SystemEngineClock implements EngineClock {
  SystemEngineClock() {
    _stopwatch.start();
  }

  final Stopwatch _stopwatch = Stopwatch();

  @override
  int nowMs() => _stopwatch.elapsedMilliseconds;

  @override
  int wallMs() => DateTime.now().millisecondsSinceEpoch;
}

/// 可控时钟，供单元测试与调试面板使用。
///
/// [advance] 同时推进单调时钟与墙钟，保持两者同步；
/// 需要单独模拟「墙钟被改」时才用 [advanceWallOnly]。
class ManualEngineClock implements EngineClock {
  ManualEngineClock({int startMs = 0, int? wallStart})
      : _now = startMs,
        _wall = wallStart ?? startMs;

  int _now;
  int _wall;

  @override
  int nowMs() => _now;

  @override
  int wallMs() => _wall;

  /// 同时推进两个时间源
  void advance(int ms) {
    _now += ms;
    _wall += ms;
  }

  /// 只推进墙钟（模拟系统时间被改动）
  void advanceWallOnly(int ms) => _wall += ms;

  set nowMsValue(int value) => _now = value;

  set wallMsValue(int value) => _wall = value;
}
