import 'dart:math' as math;

import '../models/time_card.dart';
import '../models/timer_state.dart';
import '../models/training_preset.dart';
import 'engine_clock.dart';
import 'tick_source.dart';

/// 卡片切换事件。字段与原版 `CardChangeEvent` 一一对应。
class CardChangeEvent {
  final int position;
  final TimeCard card;
  final int round;
  final int totalRounds;

  const CardChangeEvent({
    required this.position,
    required this.card,
    required this.round,
    required this.totalRounds,
  });

  @override
  String toString() =>
      'CardChangeEvent(pos=$position, ${card.label}, round=$round/$totalRounds)';
}

/// 引擎向外抛出的事件。继承后按需覆写，未覆写的事件默认忽略。
///
/// 与原版 `TimerEvents` 的四个回调同名同义。
class TimerEvents {
  const TimerEvents();

  /// 每帧回调，用于驱动环形进度这类需要连续更新的 UI。
  /// [remainingMs] 为当前卡片剩余毫秒，[totalMs] 为当前卡片总毫秒。
  void onTick(double remainingMs, double totalMs) {}

  /// 卡片切换（含开始时的第一张）
  void onCardChange(CardChangeEvent event) {}

  /// 全部序列跑完
  void onFinish() {}

  /// 最后 3 秒的每秒提示，[secondsLeft] ∈ {3, 2, 1}
  void onCountdownTick(int secondsLeft) {}
}

/// 即将到来的段位边界，供提醒排期使用。
///
/// 这是「提醒能弹出来」的关键数据：把一次计时展开成若干个**绝对时刻**，
/// 交给系统 AlarmManager 去触发，而不是等 Dart 定时器回调
/// —— 后者在息屏/后台/进程被杀后都会静默失效。
class UpcomingBoundary {
  /// 该边界即整段计时结束
  final bool isFinal;

  /// 展开序列下标（[isFinal] 为 true 时是最后一张卡片的下标）
  final int position;

  final TimeCard card;
  final int round;
  final int totalRounds;

  /// 距调用时刻的相对毫秒
  final double inMs;

  /// 绝对墙钟时间戳（毫秒）
  final int atWallMs;

  const UpcomingBoundary({
    required this.isFinal,
    required this.position,
    required this.card,
    required this.round,
    required this.totalRounds,
    required this.inMs,
    required this.atWallMs,
  });

  @override
  String toString() =>
      'Boundary(${isFinal ? "END" : "pos$position"} in ${(inMs / 1000).round()}s)';
}

/// 前台服务用的段位时间轴项：**每一个段位**的起止墙钟时刻。
///
/// 与 [UpcomingBoundary] 的分工：
///   - [UpcomingBoundary] 是「即将发生的切换点」，只喂给系统闹钟，会被
///     「短于 1 分钟的段位不发提醒」这类规则过滤掉；
///   - [ForegroundPhase] 描述「现在处于哪个段位、到几点结束」，喂给常驻通知，
///     **不做任何时长过滤** —— 通知的职责是给用户看，不是刷屏。
///
/// 存的是**绝对墙钟毫秒**而不是相对剩余量，所以拿到它的一方（可能是被冻结
/// 很久之后才醒来的后台 isolate）算一次减法就能得到正确的剩余时间，
/// 不需要任何补偿逻辑。
class ForegroundPhase {
  final String label;
  final int startWallMs;
  final int endWallMs;
  final int round;
  final int totalRounds;
  final bool isLast;

  const ForegroundPhase({
    required this.label,
    required this.startWallMs,
    required this.endWallMs,
    required this.round,
    required this.totalRounds,
    required this.isLast,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'label': label,
        'start': startWallMs,
        'end': endWallMs,
        'round': round,
        'totalRounds': totalRounds,
        'isLast': isLast,
      };

  static ForegroundPhase? fromJson(Map<String, dynamic> json) {
    final Object? label = json['label'];
    final Object? end = json['end'];
    final Object? start = json['start'];
    if (label is! String || end is! int || start is! int) return null;
    return ForegroundPhase(
      label: label,
      startWallMs: start,
      endWallMs: end,
      round: json['round'] is int ? json['round'] as int : 1,
      totalRounds: json['totalRounds'] is int ? json['totalRounds'] as int : 1,
      isLast: json['isLast'] == true,
    );
  }
}

/// 核心计时引擎。纯 Dart，不依赖 Flutter，可脱离 UI 单测。
///
/// ## 与原版的关键差异
///
/// 原版逐帧做 `remainingMs -= min(delta, 1000)`：单帧最多扣 1 秒，
/// 所以切后台回来会「凭空多出时间」，误差还会持续累积。
///
/// 本实现改为**绝对时间记账**：整个序列只有一个标量状态
/// [runElapsedMs]（已跑时长，不含暂停），
/// 当前段位与剩余时间都是它的纯函数：
///
/// ```
/// position  = 最大的 i，使得 cumulativeMs[i] <= elapsed
/// remaining = cumulativeMs[position + 1] - elapsed
/// ```
///
/// 好处是掉帧、跳帧、息屏、切后台、跨进程恢复全都退化成
/// 「重新算一次 elapsed」，不需要任何补偿逻辑，也不会有误差累积。
class TimerEngine {
  TimerEngine({EngineClock? clock, TickSource? tickSource})
      : _clock = clock ?? SystemEngineClock(),
        _tickSource = tickSource ?? const NoopTickSource();

  final EngineClock _clock;
  final TickSource _tickSource;

  TimerEvents? _events;
  TrainingPreset? _preset;
  List<TimeCard> _cards = const <TimeCard>[];

  /// 展开序列的累计毫秒边界，长度 = 卡片数 + 1，首项恒为 0。
  List<double> _cumMs = const <double>[];

  /// 已跑时长（毫秒，不含暂停）。序列的唯一真实状态。
  double _runElapsedMs = 0;

  /// 当前运行段的单调时钟起点；暂停期间无意义。
  int _runSpanStartMs = 0;

  int _startedAtWall = 0;
  TimerStatus _status = TimerStatus.idle;
  int _position = 0;
  int _lastCountdownSecond = -1;

  TimerStatus get status => _status;

  bool get isActive =>
      _status == TimerStatus.running || _status == TimerStatus.paused;

  int get position => _position;

  int get totalPositions => _cards.length;

  double get totalMs => _cumMs.isEmpty ? 0 : _cumMs.last;

  /// 当前卡片；未开始 / 已销毁时为 null
  TimeCard? get currentCard =>
      _cards.isEmpty || _position >= _cards.length ? null : _cards[_position];

  /// 当前是第几轮（1 起）
  int get currentRound {
    final TrainingPreset? preset = _preset;
    if (preset == null || preset.cards.isEmpty) return 0;
    return (_position ~/ preset.cards.length) + 1;
  }

  /// 总轮数
  int get totalRounds => _preset?.loopCount ?? 0;

  /// 已跑时长（毫秒）。运行态下按当前时钟实时计算。
  double get elapsedMs {
    if (_status == TimerStatus.running) {
      return _runElapsedMs + (_clock.nowMs() - _runSpanStartMs);
    }
    return _runElapsedMs;
  }

  double get remainingMs {
    if (_cumMs.isEmpty) return 0;
    return math.max(0, _cumMs[_position + 1] - elapsedMs);
  }

  double get currentCardMs => _cumMs.isEmpty ? 0 : _cumMs[_position + 1] - _cumMs[_position];

  // ------------------------------------------------------------------ 生命周期

  /// 开始一个方案。
  void start(TrainingPreset preset, TimerEvents events) {
    _setup(preset, events);
    if (_cards.isEmpty || totalMs <= 0) {
      _finishImmediately();
      return;
    }
    _status = TimerStatus.running;
    _runElapsedMs = 0;
    _runSpanStartMs = _clock.nowMs();
    _emitCardChange();
    _sync();
    if (_status == TimerStatus.running) {
      _tickSource.start(_onTick);
    }
  }

  /// 从持久化快照恢复。
  ///
  /// [snapshot] 里记录了快照时刻的已跑进度与墙钟时间；
  /// 若快照是在运行态下拍的，则把「快照到现在」的墙钟时间补进已跑时长。
  /// 返回 false 表示该快照已经跑完或已失效，调用方应丢弃它。
  RestoreOutcome restore(RunningState snapshot, TimerEvents events) {
    _setup(snapshot.preset, events);
    if (_cards.isEmpty || totalMs <= 0) return RestoreOutcome.none;

    final int savedPos = snapshot.position.clamp(0, _cards.length - 1);
    final double savedElapsed = _cumMs[savedPos] +
        (_cumMs[savedPos + 1] - _cumMs[savedPos] - snapshot.cardRemainingMs);

    double elapsed = math.max(0, savedElapsed);
    if (snapshot.wasRunning) {
      final int wallGap = _clock.wallMs() - snapshot.pausedAt;
      if (wallGap > 0) elapsed += wallGap;
    }

    // 已经跑过头：说明这段计时在离开期间就结束了。
    // 明确区分「没有可恢复的计时」和「上一次已自然结束」，
    // 让上层能给出合适的反馈，而不是把它当成一次莫名其妙的清空。
    if (elapsed >= totalMs) return RestoreOutcome.alreadyFinished;

    _setElapsed(elapsed);
    _status = snapshot.wasRunning ? TimerStatus.running : TimerStatus.paused;
    if (_status == TimerStatus.running) {
      _runSpanStartMs = _clock.nowMs();
    }
    _emitCardChange();
    _sync();
    if (_status == TimerStatus.running) {
      _tickSource.start(_onTick);
    }
    return isActive ? RestoreOutcome.restored : RestoreOutcome.none;
  }

  void pause() {
    if (_status != TimerStatus.running) return;
    _runElapsedMs = elapsedMs; // 先冻结累计，再改状态
    _tickSource.stop();
    _status = TimerStatus.paused;
  }

  void resume() {
    if (_status != TimerStatus.paused) return;
    _runSpanStartMs = _clock.nowMs();
    _status = TimerStatus.running;
    _lastCountdownSecond = -1;
    _sync();
    if (_status == TimerStatus.running) {
      _tickSource.start(_onTick);
    }
  }

  /// 跳过当前卡片，直接进入下一段。
  ///
  /// 与原版一致：已结束状态下调用无副作用。
  /// 与原版不同：暂停状态下跳过会保持暂停，不会偷偷开始计时
  /// （原版的 `skip()` 会重新挂上 rAF，等于被动恢复运行）。
  void skip() {
    if (_status != TimerStatus.running && _status != TimerStatus.paused) return;
    final int nextIndex = _position + 1;
    if (nextIndex >= _cards.length) {
      _runElapsedMs = totalMs;
      _finish();
      return;
    }
    _lastCountdownSecond = -1;
    _setElapsed(_cumMs[nextIndex]);
    _sync();
  }

  /// 回到首段并重新计时。
  void reset() {
    if (_cards.isEmpty) return;
    _tickSource.stop();
    _lastCountdownSecond = -1;
    _status = TimerStatus.running;
    _runElapsedMs = 0;
    _runSpanStartMs = _clock.nowMs();
    _startedAtWall = _clock.wallMs();
    _emitCardChange();
    _sync();
    if (_status == TimerStatus.running) {
      _tickSource.start(_onTick);
    }
  }

  void destroy() {
    _tickSource.stop();
    _status = TimerStatus.idle;
    _events = null;
    _preset = null;
    _cards = const <TimeCard>[];
    _cumMs = const <double>[];
    _runElapsedMs = 0;
    _position = 0;
    _lastCountdownSecond = -1;
  }

  // ------------------------------------------------------------------ 状态导出

  TimerState? getState() {
    final TrainingPreset? preset = _preset;
    if (preset == null || _cards.isEmpty) return null;
    return TimerState(
      preset: preset,
      position: _position,
      totalPositions: _cards.length,
      remainingMs: remainingMs,
      status: _status,
      startedAt: _startedAtWall,
      pausedAt: _clock.wallMs(),
    );
  }

  /// 生成持久化快照，供跨进程恢复使用。
  RunningState? snapshot() {
    final TrainingPreset? preset = _preset;
    if (preset == null || _cards.isEmpty) return null;
    return RunningState(
      preset: preset,
      position: _position,
      cardRemainingMs: remainingMs,
      pausedAt: _clock.wallMs(),
      startedAt: _startedAtWall,
      wasRunning: _status == TimerStatus.running,
    );
  }

  /// 列出后续所有段位边界，按时间先后排序。
  ///
  /// [maxItems] 用来限制排期数量——Android 单应用精确闹钟有数量上限，
  /// 超长方案（如 2 张卡 × 100 循环）不能一股脑全排。
  /// 裁剪时**必须保留最后一项**（结束提醒绝不能被裁掉）。
  List<UpcomingBoundary> upcomingBoundaries({int maxItems = 32}) {
    final TrainingPreset? preset = _preset;
    if (preset == null || _cards.isEmpty) return const <UpcomingBoundary>[];

    final double elapsed = elapsedMs;
    final int cardCount = preset.cards.length;
    final int wallNow = _clock.wallMs();
    final int lastIndex = _cards.length - 1;
    final int first = math.min(_position + 1, _cards.length);

    final List<UpcomingBoundary> out = <UpcomingBoundary>[];
    for (int i = first; i <= _cards.length; i++) {
      final double inMs = _cumMs[i] - elapsed;
      if (inMs <= 0) continue;
      final bool isFinal = i == _cards.length;
      final int pos = isFinal ? lastIndex : i;
      out.add(UpcomingBoundary(
        isFinal: isFinal,
        position: pos,
        card: _cards[pos],
        round: cardCount == 0 ? 1 : (pos ~/ cardCount) + 1,
        totalRounds: preset.loopCount,
        inMs: inMs,
        atWallMs: wallNow + inMs.round(),
      ));
    }

    if (out.length <= maxItems) return out;
    return <UpcomingBoundary>[
      ...out.sublist(0, maxItems - 1),
      out.last,
    ];
  }

  /// 从**当前段位**开始，列出后续每个段位的起止绝对时刻。
  ///
  /// 与 [upcomingBoundaries] 的关键差异是「包含当前段位」：常驻通知要显示的
  /// 是「我现在在做什么、还剩多久」，而不是「下一个切换点是几点」。
  ///
  /// [maxItems] 限制下发到后台 isolate 的数据量（超长方案如 2 卡 × 100 循环
  /// 有 200 段）。裁剪时**保留首项与末项**：首项是通知立刻要显示的，末项标记
  /// 整段结束，两头都不能丢。
  List<ForegroundPhase> foregroundPhases({int maxItems = 128}) {
    final TrainingPreset? preset = _preset;
    if (preset == null || _cards.isEmpty) return const <ForegroundPhase>[];

    final double elapsed = elapsedMs;
    final int wallNow = _clock.wallMs();
    final int cardCount = preset.cards.length;

    final List<ForegroundPhase> out = <ForegroundPhase>[];
    for (int i = _position; i < _cards.length; i++) {
      final double startOff = _cumMs[i] - elapsed;
      final double endOff = _cumMs[i + 1] - elapsed;
      // 已经跑完的段位直接丢掉；只有当前段位可能 startOff < 0
      if (endOff <= 0) continue;
      out.add(ForegroundPhase(
        label: _cards[i].label,
        startWallMs: wallNow + math.max(0, startOff).round(),
        endWallMs: wallNow + endOff.round(),
        round: cardCount == 0 ? 1 : (i ~/ cardCount) + 1,
        totalRounds: preset.loopCount,
        isLast: i == _cards.length - 1,
      ));
    }

    if (out.length <= maxItems) return out;
    return <ForegroundPhase>[
      ...out.sublist(0, maxItems - 1),
      out.last,
    ];
  }

  // ------------------------------------------------------------------ 内部

  void _setup(TrainingPreset preset, TimerEvents events) {
    _tickSource.stop();
    _events = events;
    _preset = preset;
    _cards = preset.cards.isEmpty || preset.loopCount < 1
        ? const <TimeCard>[]
        : preset.expand();
    _cumMs = _buildCumulative(_cards);
    _position = 0;
    _runElapsedMs = 0;
    _runSpanStartMs = _clock.nowMs();
    _startedAtWall = _clock.wallMs();
    _lastCountdownSecond = -1;
    _status = TimerStatus.idle;
  }

  static List<double> _buildCumulative(List<TimeCard> cards) {
    final List<double> out = <double>[0];
    double acc = 0;
    for (final TimeCard c in cards) {
      acc += c.duration * 1000.0;
      out.add(acc);
    }
    return out;
  }

  void _onTick() {
    if (_status != TimerStatus.running) return;
    _sync();
  }

  /// 依据当前 elapsed 重算 position / remaining 并广播事件。
  void _sync() {
    if (_cards.isEmpty) return;
    final double elapsed = elapsedMs;
    if (elapsed >= totalMs) {
      _runElapsedMs = totalMs;
      _position = _cards.length - 1;
      _finish();
      return;
    }

    final int newPosition = _positionFor(elapsed);
    final bool moved = newPosition != _position;
    _position = newPosition;

    if (moved) _emitCardChange();

    final double cardTotal = currentCardMs;
    final double remaining = math.max(0, _cumMs[_position + 1] - elapsed);
    _events?.onTick(remaining, cardTotal);
    _maybeCountdown(remaining);
  }

  /// 最大的 i，使得 cumulativeMs[i] <= elapsed（以当前位置为起点双向探测，
  /// 正常前进时是 O(1) 的）。
  int _positionFor(double elapsed) {
    int i = _position.clamp(0, _cards.length - 1);
    while (i + 1 < _cards.length && _cumMs[i + 1] <= elapsed) {
      i++;
    }
    while (i > 0 && _cumMs[i] > elapsed) {
      i--;
    }
    return i;
  }

  /// 直接给定已跑时长，并让后续 [elapsedMs] 从该值继续。
  void _setElapsed(double value) {
    _runElapsedMs = value;
    if (_status == TimerStatus.running) {
      _runSpanStartMs = _clock.nowMs();
    }
  }

  void _maybeCountdown(double remaining) {
    if (_status != TimerStatus.running) return;
    if (remaining > 0 && remaining <= 3000) {
      final int secondsLeft = (remaining / 1000).ceil();
      if (secondsLeft != _lastCountdownSecond) {
        _lastCountdownSecond = secondsLeft;
        _events?.onCountdownTick(secondsLeft);
      }
    }
  }

  void _finish() {
    _tickSource.stop();
    _status = TimerStatus.finished;
    _events?.onTick(0, currentCardMs);
    _events?.onFinish();
  }

  void _finishImmediately() {
    _tickSource.stop();
    _status = TimerStatus.finished;
    _events?.onFinish();
  }

  void _emitCardChange() {
    final TimerEvents? events = _events;
    final TrainingPreset? preset = _preset;
    if (events == null || preset == null || _cards.isEmpty) return;
    final int cardCount = preset.cards.length;
    events.onCardChange(
      CardChangeEvent(
        position: _position,
        card: _cards[_position],
        round: cardCount == 0 ? 1 : (_position ~/ cardCount) + 1,
        totalRounds: preset.loopCount,
      ),
    );
  }
}
