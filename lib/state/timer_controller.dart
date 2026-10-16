import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart'
    show DataCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../engine/timer_engine.dart';
import '../engine/ticker_tick_source.dart';
import '../models/app_settings.dart';
import '../models/time_card.dart';
import '../models/timer_state.dart';
import '../models/training_preset.dart';
import '../services/foreground_timer_service.dart'
    show ForegroundTimerService, describeForeground;
import '../services/notification_service.dart'
    show AlarmCapability, NotificationService;
import 'services.dart';

/// 计时页的「粗粒度」状态：只在段位切换 / 计时状态变化时更新。
///
/// 每一帧都在变的数值（环形进度、大数字）走 [TimerController.ringProgress]
/// 与 [TimerController.secondsLeft] 两个 ValueNotifier，
/// 由对应的 ValueListenableBuilder 局部消费——
/// 这是原版「UI 更新仅在剩余秒数变化时触发」的 Flutter 对应物，
/// 避免一秒 60 次整页重建。
class TimerViewState {
  const TimerViewState({
    this.hasPreset = false,
    this.status = TimerStatus.idle,
    this.presetName = '',
    this.currentRound = 0,
    this.totalRounds = 0,
    this.currentLabel = '',
    this.currentColor = '#ff6b35',
    this.alarmHint,
    this.scheduledAlerts = 0,
  });

  final bool hasPreset;
  final TimerStatus status;
  final String presetName;
  final int currentRound;
  final int totalRounds;
  final String currentLabel;
  final String currentColor;

  /// 提醒能力的诊断信息（权限没给全时 UI 顶部提示）
  final String? alarmHint;

  /// 已写入系统的提醒排期条数。0 表示排期没成功（对照 alarmHint 找原因）
  final int scheduledAlerts;

  bool get isRunning => status == TimerStatus.running;
  bool get isPaused => status == TimerStatus.paused;
  bool get isFinished => status == TimerStatus.finished;

  TimerViewState copyWith({
    TimerStatus? status,
    int? currentRound,
    int? totalRounds,
    String? currentLabel,
    String? currentColor,
    String? alarmHint,
    int? scheduledAlerts,
  }) =>
      TimerViewState(
        hasPreset: hasPreset,
        status: status ?? this.status,
        presetName: presetName,
        currentRound: currentRound ?? this.currentRound,
        totalRounds: totalRounds ?? this.totalRounds,
        currentLabel: currentLabel ?? this.currentLabel,
        currentColor: currentColor ?? this.currentColor,
        alarmHint: alarmHint ?? this.alarmHint,
        scheduledAlerts: scheduledAlerts ?? this.scheduledAlerts,
      );
}

/// 计时器控制器：引擎 + 提醒 + 声音 + 震动 + 常亮的总装车间。
///
/// 与原版 `stores/timer.ts` 的职责一一对应，多出来的部分是
/// 原版没做成的三件事：后台提醒排期、屏幕常亮、运行状态跨进程恢复。
class TimerController extends Notifier<TimerViewState> {
  TimerEngine? _engine;

  /// 后台 isolate 的 `need-sync` 消息回调。留着是为了在 dispose 时注销。
  DataCallback? _syncListener;

  @override
  TimerViewState build() {
    ref.onDispose(_teardown);
    // 后台 isolate 发现时间轴用尽时会喊一声。这个回调走的是端口消息，
    // 不依赖 Flutter 帧循环 —— 所以即便 App 退到后台不再渲染，它照样能执行，
    // 有机会把新的时间轴补下去。
    _syncListener =
        ForegroundTimerService.addSyncRequestListener(_syncForeground);
    return const TimerViewState();
  }

  // ------------------------------------------------------------------ 面向 UI 的细粒度通道

  /// 环形进度 0..1，每帧更新
  final ValueNotifier<double> ringProgress = ValueNotifier<double>(0);

  /// 当前卡片剩余整秒，仅在该值变化时更新
  final ValueNotifier<int> secondsLeft = ValueNotifier<int>(0);

  /// 运行中落盘节流：两次快照之间的最小间隔
  static const int _snapshotIntervalMs = 10000;
  int _lastSnapshotMs = 0;

  // ------------------------------------------------------------------ 对外操作

  /// 开始一个方案（含首页的临时快速模板）。
  Future<void> start(TrainingPreset preset) async {
    _lastSnapshotMs = 0; // 让第一帧就落一次盘
    _applySettingsSafe();
    final TimerEngine engine = _ensureEngine();
    engine.start(preset, _bridge);
    _syncFromEngine();

    // 先排期、后请求权限：
    // ① 权限弹窗/跳系统页不应拖延甚至打断排期；
    // ② 排期失败不能被权限路径的异常连坐（home 页是 fire-and-forget 调用本方法）。
    await _scheduleAlerts();
    // 拉起常驻通知。它同时承担两件事：**保证进程不被 ROM 冻结/强杀**
    //（进程一被 force-stop，刚排好的闹钟会被系统一并清空），
    // 以及让用户在锁屏上就能看到当前阶段与剩余时间。
    // 不 await：服务启动要走一次冷启动 isolate，不该拖住 start() 的返回。
    unawaited(_syncForeground());
    unawaited(_requestPermissionsSafe());
    unawaited(_wakeLock(true)); // 常亮是尽力而为，不阻塞启动流程
  }

  /// 请求提醒相关权限。结果只影响「准不准时」，不影响「有没有排期」。
  Future<void> _requestPermissionsSafe() async {
    try {
      final NotificationService svc = ref.read(notificationServiceProvider);
      final bool exactBefore = svc.exactAllowed;
      final AlarmCapability cap = await svc.ensurePermissions();
      state = state.copyWith(alarmHint: cap.problemHint);
      // 只有排期模式真的切换了（精确 ↔ 大致准时）才值得重排一次，
      // 否则就是无意义的「取消再排」×2
      if (svc.exactAllowed != exactBefore) {
        await _scheduleAlerts();
      }
    } catch (_) {
      // 权限链路异常不影响计时
    }
  }

  Future<void> pause() async {
    final TimerEngine? engine = _engine;
    if (engine == null) return;
    engine.pause();
    _syncFromEngine();
    // 暂停时不再需要排期提醒（恢复时会重新排）
    await ref.read(notificationServiceProvider).cancelAll();
    // 常驻通知**不停**：暂停也是计时会话的一部分，进程仍需保活，
    // 否则用户暂停后切后台，回来时计时现场可能已经丢了。
    unawaited(_syncForeground());
    await _saveRunningState();
  }

  Future<void> resume() async {
    final TimerEngine? engine = _engine;
    if (engine == null) return;
    engine.resume();
    _syncFromEngine();
    ref.read(soundServiceProvider).playChime();
    ref.read(hapticsServiceProvider).playTransition();
    await _scheduleAlerts();
    unawaited(_syncForeground());
  }

  Future<void> skip() async {
    final TimerEngine? engine = _engine;
    if (engine == null) return;
    engine.skip();
    _syncFromEngine();
    await _scheduleAlerts();
    unawaited(_syncForeground());
  }

  Future<void> reset() async {
    final TimerEngine? engine = _engine;
    if (engine == null) return;
    engine.reset();
    _syncFromEngine();
    await ref.read(hapticsServiceProvider).cancel();
    await _scheduleAlerts();
    unawaited(_syncForeground());
  }

  /// 离开计时页：彻底收尾
  Future<void> exit() async {
    _engine?.destroy();
    await ref.read(hapticsServiceProvider).cancel();
    await ref.read(notificationServiceProvider).cancelAll();
    await ref.read(foregroundServiceProvider).stop();
    await ref.read(runningStateRepositoryProvider).clear();
    await _wakeLock(false);
    ringProgress.value = 0;
    secondsLeft.value = 0;
    state = TimerViewState(alarmHint: state.alarmHint);
  }

  /// 应用启动时尝试恢复上次中断的计时。
  ///
  /// 原版只写不读的 `running_state`，在这里真正被消费。
  /// 三种结果分别处理：恢复成功 / 离开期间已自然结束 / 无可恢复内容。
  Future<RestoreOutcome> tryRestore() async {
    final RunningState? snapshot =
        await ref.read(runningStateRepositoryProvider).get();
    if (snapshot == null) return RestoreOutcome.none;

    _applySettingsSafe();
    final TimerEngine engine = _ensureEngine();
    final RestoreOutcome outcome = engine.restore(snapshot, _bridge);
    if (outcome != RestoreOutcome.restored) {
      await ref.read(runningStateRepositoryProvider).clear();
      // 上一次计时在离开期间就结束了：顺手收掉可能还挂着的常驻通知。
      // 不收的话用户会看到一条停在「剩余 00:00」的通知，而 App 里明明没有计时。
      await ref.read(foregroundServiceProvider).stop();
      return outcome;
    }
    _syncFromEngine();
    await _scheduleAlerts();
    unawaited(_syncForeground());
    if (engine.status == TimerStatus.running) {
      unawaited(_wakeLock(true)); // 不阻塞恢复流程（个别机型 wakelock 通道会挂起）
    }
    return RestoreOutcome.restored;
  }

  /// App 退到后台时保存现场（进程被杀也能恢复）。
  Future<void> saveForBackground() async {
    final TimerEngine? engine = _engine;
    if (engine == null || !engine.isActive) return;
    await _saveRunningState();
  }

  // ------------------------------------------------------------------ 引擎事件处理

  void _handleTick(double remainingMs, double totalMs) {
    final double progress =
        totalMs > 0 ? (1 - remainingMs / totalMs).clamp(0.0, 1.0) : 0.0;
    ringProgress.value = progress;

    final int secs = remainingMs <= 0 ? 0 : (remainingMs / 1000).ceil();
    if (secs != secondsLeft.value) {
      secondsLeft.value = secs;
    }

    // 运行中每 10 秒落一次盘：进程被系统回收、甚至崩溃时，
    // 留下的现场最多只差 10 秒，不至于整段计时凭空消失。
    final int wallNow = DateTime.now().millisecondsSinceEpoch;
    if (wallNow - _lastSnapshotMs >= _snapshotIntervalMs) {
      _lastSnapshotMs = wallNow;
      _saveRunningState();
    }
  }

  void _handleCardChange(CardChangeEvent event) {
    final TimerEngine? engine = _engine;
    state = state.copyWith(
      status: engine?.status,
      currentRound: event.round,
      totalRounds: event.totalRounds,
      currentLabel: event.card.label,
      currentColor: event.card.color,
    );
    // 阶段切换提示：一声短「滴」+ 两次短震
    ref.read(soundServiceProvider).playTick();
    ref.read(hapticsServiceProvider).playTransition();
    // 段位变了，常驻通知立刻跟上。用 unawaited：这里是同步回调，
    // 而且通知晚一两百毫秒刷新没有任何影响。
    unawaited(_syncForeground());
  }

  void _handleCountdown(int secondsLeft) {
    ref.read(soundServiceProvider).playTick();
  }

  void _handleFinish() {
    final TimerEngine? engine = _engine;
    state = state.copyWith(
      status: TimerStatus.finished,
      currentRound: engine?.totalRounds ?? state.totalRounds,
    );
    ringProgress.value = 1;
    secondsLeft.value = 0;

    // 结束提醒：5 秒旋律 + 三次短震
    ref.read(soundServiceProvider).playFinish();
    ref.read(hapticsServiceProvider).playFinish();

    // 注意：这里【不要】cancelAll —— 结束提醒的闹钟此刻正在触发，
    // 立刻取消会和系统投递赛跑，把「训练完成」通知杀掉。
    // 方案已结束、没有未来边界，残留排期本就不存在。
    ref.read(runningStateRepositoryProvider).clear();
    _wakeLock(false);

    // 常驻通知改成「训练完成」并留在通知栏，直到用户离开计时页才停。
    // 直接 stop 的话，用户切后台回来会以为计时被重置了。
    unawaited(_syncForeground());
  }

  // ------------------------------------------------------------------ 内部

  late final TimerEvents _bridge = _EngineBridge(
    onTickCallback: _handleTick,
    onCardChangeCallback: _handleCardChange,
    onCountdownTickCallback: _handleCountdown,
    onFinishCallback: _handleFinish,
  );

  TimerEngine _ensureEngine() =>
      _engine ??= TimerEngine(tickSource: PlainTickerSource());

  /// 把持久化的开关即时反映到服务上。
  ///
  /// 全程防护：这里的任何异常都会顺着 `start()` 的 fire-and-forget 调用
  /// 变成无人处理的异步错误，把后面的排期一起带走（真机排查过的坑）。
  void _applySettingsSafe() {
    try {
      final AppSettings settings =
          ref.read(settingsControllerProvider).value ?? AppSettings.defaults;
      ref.read(soundServiceProvider).enabled = settings.soundEnabled;
      ref.read(hapticsServiceProvider).enabled = settings.vibrationEnabled;
    } catch (_) {
      // 开关读不到就保持默认值，绝不让设置问题阻塞计时
    }
  }

  bool get _alertsEnabled =>
      ref.read(settingsControllerProvider).value?.notificationEnabled ?? true;

  /// 小于 1 分钟的段位不发边界提醒（避免短段位刷屏）；结束提醒始终保留。
  /// 用户实测反馈后新增的规则。
  static const int _minNotifySegmentSec = 60;

  Future<void> _scheduleAlerts() async {
    final TimerEngine? engine = _engine;
    if (engine == null || !engine.isActive) return;
    if (!_alertsEnabled) {
      await ref.read(notificationServiceProvider).cancelAll();
      state = state.copyWith(scheduledAlerts: 0);
      return;
    }
    final NotificationService svc = ref.read(notificationServiceProvider);

    // 过滤：只提醒时长 ≥ 1 分钟的段位边界；结束提醒无条件保留
    final List<UpcomingBoundary> boundaries = <UpcomingBoundary>[
      for (final UpcomingBoundary b in engine.upcomingBoundaries())
        if (b.isFinal || b.card.duration >= _minNotifySegmentSec) b,
    ];

    await svc.scheduleAlerts(state.presetName, boundaries);

    // 排期结果可视化：写进了系统几条，让「提醒到底排上没有」有据可查
    final int count = await svc.pendingNotificationCount();
    String? hint = state.alarmHint;
    if (svc.lastScheduleError != null) {
      hint = '提醒排期失败：${svc.lastScheduleError}';
    } else if (count == 0) {
      hint = '系统提醒未排期，请检查通知与「闹钟和提醒」权限';
    }
    state = state.copyWith(
      scheduledAlerts: count < 0 ? 0 : count,
      alarmHint: hint,
    );
  }

  /// 把当前状态同步到常驻通知。
  ///
  /// 这是引擎与前台服务之间**唯一**的接缝：计时活着的每一刻把状态同步过去，
  /// 空闲或已结束时把服务停掉。
  ///
  /// **刻意不缓存「服务有没有在跑」**。之前缓过，结果被现实打脸：结束提醒的
  /// 原生接收器会在投递时把服务停掉（见 `SetBeatAlertReceiver`），Dart 侧的
  /// 缓存对此一无所知，于是「服务明明该在跑却再也起不来」。
  /// `start()` 内部本来就做了「已在跑就只更新」的判断，交给它就行 ——
  /// 多一次平台通道调用的代价，远小于一个会过期的状态位。
  ///
  /// 任何异常都吞掉：常驻通知是「尽力而为」的能力，它失败不能影响计时本身。
  Future<void> _syncForeground() async {
    final TimerEngine? engine = _engine;
    final ForegroundTimerService svc = ref.read(foregroundServiceProvider);

    // 结束态也走 stop：计时已完，不需要保活；而常驻通知继续挂着的话，
    // 「训练完成」会同时出现在常驻通知和结束提醒里，看起来就是发了两条。
    if (engine == null ||
        engine.status == TimerStatus.idle ||
        engine.status == TimerStatus.finished) {
      await svc.stop();
      return;
    }

    try {
      final String status = engine.status.name;
      final List<ForegroundPhase> phases = engine.foregroundPhases();
      final int pausedRemaining =
          engine.status == TimerStatus.paused ? engine.remainingMs.round() : 0;
      final String presetName =
          engine.getState()?.preset.name ?? state.presetName;

      // 文案由共享的 describeForeground 推导，与后台 isolate 每秒重算的
      // 是同一套规则 —— 两边各写一份的话，初始那一下必然对不上。
      final ({String title, String text}) d = describeForeground(
        presetName: presetName,
        status: status,
        phases: phases,
        nowMs: DateTime.now().millisecondsSinceEpoch,
        pausedRemainingMs: pausedRemaining,
      );

      await svc.start(
        presetName: presetName,
        title: d.title,
        text: d.text,
        phases: phases,
        status: status,
        pausedRemainingMs: pausedRemaining,
      );
    } catch (_) {
      // 常驻通知失败不影响计时与闹钟排期
    }
  }

  Future<void> _saveRunningState() async {
    final TimerEngine? engine = _engine;
    if (engine == null) return;
    final RunningState? snapshot = engine.snapshot();
    if (snapshot == null) return;
    await ref.read(runningStateRepositoryProvider).save(snapshot);
  }

  void _syncFromEngine() {
    final TimerEngine? engine = _engine;
    if (engine == null || engine.status == TimerStatus.idle) return;
    final TimerState? snapshot = engine.getState();
    if (snapshot == null) return;

    final TimeCard? card = engine.currentCard;
    state = TimerViewState(
      hasPreset: true,
      status: snapshot.status,
      presetName: snapshot.preset.name,
      currentRound: engine.currentRound,
      totalRounds: engine.totalRounds,
      currentLabel: card?.label ?? state.currentLabel,
      currentColor: card?.color ?? state.currentColor,
      alarmHint: state.alarmHint,
    );
  }


  /// 屏幕常亮开关。个别设备/平台上 wakelock 插件可能抛错，
  /// 失败只影响省电体验，绝不能打断计时。
  Future<void> _wakeLock(bool enable) async {
    try {
      if (enable) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {}
  }

  void _teardown() {
    final DataCallback? listener = _syncListener;
    if (listener != null) {
      ForegroundTimerService.removeSyncRequestListener(listener);
      _syncListener = null;
    }
    _engine?.destroy();
    ringProgress.dispose();
    secondsLeft.dispose();
  }
}

/// 引擎事件桥：把引擎回调转成控制器方法。
/// 单独成类只是为了不把 TimerEvents 的方法名混进控制器公开面。
class _EngineBridge extends TimerEvents {
  _EngineBridge({
    required this.onTickCallback,
    required this.onCardChangeCallback,
    required this.onCountdownTickCallback,
    required this.onFinishCallback,
  });

  final void Function(double remainingMs, double totalMs) onTickCallback;
  final void Function(CardChangeEvent event) onCardChangeCallback;
  final void Function(int secondsLeft) onCountdownTickCallback;
  final void Function() onFinishCallback;

  @override
  void onTick(double remainingMs, double totalMs) =>
      onTickCallback(remainingMs, totalMs);

  @override
  void onCardChange(CardChangeEvent event) => onCardChangeCallback(event);

  @override
  void onCountdownTick(int secondsLeft) => onCountdownTickCallback(secondsLeft);

  @override
  void onFinish() => onFinishCallback();
}

/// 计时器状态的唯一入口。
final NotifierProvider<TimerController, TimerViewState> timerControllerProvider =
    NotifierProvider<TimerController, TimerViewState>(TimerController.new);
