import 'training_preset.dart';

/// 计时器运行时状态。
///
/// `remainingMs` 用 double 保留小数精度——原版是逐帧累减，必须限幅 1000ms 才能
/// 抑制误差；Flutter 版改为绝对时间换算，仍保留 double 以示精度不被截断。
enum TimerStatus {
  idle,
  running,
  paused,
  finished;

  String get wireName => name;

  static TimerStatus fromWire(String? value) => switch (value) {
        'running' => TimerStatus.running,
        'paused' => TimerStatus.paused,
        'finished' => TimerStatus.finished,
        _ => TimerStatus.idle,
      };
}

class TimerState {
  final TrainingPreset preset;

  /// 当前在展开序列中的位置
  final int position;

  /// 展开序列总长度
  final int totalPositions;

  /// 当前卡片剩余毫秒
  final double remainingMs;

  final TimerStatus status;

  final int startedAt;

  /// 暂停时的时间戳（毫秒），后台恢复用
  final int pausedAt;

  const TimerState({
    required this.preset,
    required this.position,
    required this.totalPositions,
    required this.remainingMs,
    required this.status,
    required this.startedAt,
    required this.pausedAt,
  });

  /// 当前卡片在展开序列中的索引对应的卡片。
  /// 结束时可能越界，调用方需自行判断 —— 用可空返回避免抛异常。
  bool get isFinished => status == TimerStatus.finished;
}

/// 跨进程恢复的结果。
///
/// 区分「没有快照」/「恢复成功」/「离开期间已经自然结束」三种情况——
/// 早前只用一个 bool，把第三种情况当成失败静默清空，
/// 用户看到的就是「切后台回来计时被重置了」。
enum RestoreOutcome {
  /// 没有可恢复的快照
  none,

  /// 成功恢复到运行中或暂停中
  restored,

  /// 上一次计时在离开期间已经跑完
  alreadyFinished,
}

/// 持久化的运行状态，用于跨进程恢复计时。
///
/// 原版只写不读（`resumeFromBackground()` 从未实现），Flutter 版补齐读取链路。
class RunningState {
  final TrainingPreset preset;
  final int position;
  final double cardRemainingMs;

  /// 快照时刻的墙钟时间戳（毫秒）。沿用原版字段名 `pausedAt`。
  /// 快照时计时器可能正在运行 —— 是否运行由 [wasRunning] 表示。
  final int pausedAt;

  final int startedAt;

  /// 新增字段（原版没有）：快照时计时器是否处于运行态。
  /// 为 true 时，恢复需要把「快照到现在的墙钟时间」补进已跑时长。
  /// 旧数据缺该字段时按 false（视为暂停）处理，向后兼容。
  final bool wasRunning;

  const RunningState({
    required this.preset,
    required this.position,
    required this.cardRemainingMs,
    required this.pausedAt,
    required this.startedAt,
    this.wasRunning = false,
  });

  factory RunningState.fromJson(Map<String, dynamic> json) => RunningState(
        preset: TrainingPreset.fromJson(json['preset'] as Map<String, dynamic>),
        position: (json['position'] as num).toInt(),
        cardRemainingMs: (json['cardRemainingMs'] as num).toDouble(),
        pausedAt: (json['pausedAt'] as num).toInt(),
        startedAt: (json['startedAt'] as num).toInt(),
        wasRunning: json['wasRunning'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'preset': preset.toJson(),
        'position': position,
        'cardRemainingMs': cardRemainingMs,
        'pausedAt': pausedAt,
        'startedAt': startedAt,
        'wasRunning': wasRunning,
      };
}
