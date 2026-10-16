import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../engine/timer_engine.dart';
import '../utils/format.dart';

/// 前台服务 —— 计时期间的「保命符」。
///
/// ## 为什么必须有它
///
/// 国产 ROM（ColorOS / MIUI / EMUI / OriginOS）对不在白名单里的后台应用会
/// 冻结甚至 force-stop。而 **Android 在 force-stop 一个应用时会连带清空它
/// 全部 AlarmManager 闹钟** —— 这是 AOSP 行为，不是厂商 bug。
///
/// 表现出来就是本项目真机踩到的那个现象：
///   · 3 秒测试提醒能弹（应用还在前台，闹钟没被清）；
///   · 1 分钟计时到点什么都不发生（应用已被干掉，闹钟早没了）；
///   · 模拟器一切正常（没有省电 / 冻结逻辑）。
///
/// 前台服务（带常驻通知）是 Android 上唯一能让系统「不敢随便杀」的合法手段。
/// 它顺带解决了第二件事：常驻通知里显示当前阶段与剩余时间，
/// 锁屏时也一眼能看到进度。
///
/// ## 三条设计约束
///
/// **1. 下发时间轴，而不是每秒推剩余量。**
/// 主 isolate 只在状态变化时把整条 [ForegroundPhase] 时间轴推给后台 isolate；
/// 后台 isolate 每秒自己用 `endWallMs - now` 算剩余。这样即使主 isolate 被
/// 冻结，倒计时照样走得准。反过来一旦主 isolate 停了，通知就会永久卡住。
///
/// **2. 文案逻辑只有一份。**
/// [describeForeground] 同时被主 isolate（生成初始通知）和后台 isolate
/// （每秒刷新）调用。两份实现迟早会漂移，表现为「刚启动那一瞬文案对不上」。
///
/// **3. 只在文案变化时碰系统通知。**
/// `updateService` 是一次跨 isolate + 跨 MethodChannel 的调用。低端机上每秒
/// 无条件打一次是实打实的开销，而通知文本本来就只精确到秒。
class ForegroundTimerService {
  /// 常驻通知的渠道 id。与 [NotificationService] 的提醒渠道**刻意分开**：
  /// 常驻通知是 LOW 重要性（无声、不弹、不占角标），而阶段提醒是 MAX
  /// 重要性（要声音、要横幅）。共用渠道会把两者的重要性拉平，双双失能。
  static const String _channelId = 'setbeat_timer_running';
  static const String _channelName = '计时进行中';
  static const String _channelDescription = '计时期间常驻显示当前阶段与剩余时间';

  /// 服务 id。固定值，避免重复 start 产生多条常驻通知。
  static const int _serviceId = 0x5E7B1000;

  static bool _configured = false;

  /// 原生实现根本不存在（单元测试、Web、未注册插件的宿主）。
  ///
  /// 命中一次之后就不再尝试：否则每次段位切换都会打一次必然失败的平台调用，
  /// 刷屏且白费。真机上永远不会走到这里。
  bool _platformUnavailable = false;

  /// 在 `main()` 里调用一次。幂等，重复调用无副作用。
  ///
  /// 必须在任何服务调用之前跑完，否则插件会抛 `ServiceNotInitializedException`。
  static void configure() {
    if (_configured) return;
    _configured = true;

    // 建立与后台 isolate 的双向端口。少了它 sendDataToMain / sendDataToTask
    // 会静默丢弃 —— 不报错，只是消息不见了。
    FlutterForegroundTask.initCommunicationPort();

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: _channelName,
        channelDescription: _channelDescription,
        // LOW：只安静躺在通知栏。一个每秒刷新的常驻通知如果会响会弹是灾难。
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
        showWhen: false,
        // 关键：常驻通知绝不能计入桌面角标。否则用户看到的「32」里混着
        // 一条「计时进行中」，数字角标的语义就毁了。
        showBadge: false,
        enableVibration: false,
        playSound: false,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // 1 秒一次：通知要显示秒级倒计时
        eventAction: ForegroundTaskEventAction.repeat(1000),
        // 开机自启无意义：计时状态本身不跨重启，恢复流程由主 isolate 负责
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        // PARTIAL_WAKE_LOCK：屏幕可灭但 CPU 不睡，保住秒级倒计时的刷新。
        // 一场训练最多几十分钟，这点耗电换「提醒一定准」是划算的。
        // 想省电可以改 false：代价是设备休眠期间通知不刷新，醒来才跳回正确值
        //（时间轴存的是绝对时刻，所以跳回去之后仍然是对的）。
        allowWakeLock: true,
        allowWifiLock: false,
        // 服务被系统杀掉后允许自动重启，配合落盘的时间轴续上
        allowAutoRestart: true,
      ),
    );
  }

  /// 系统侧的真实运行态。用于自检面板展示。
  /// 这个值是问系统要的 —— 服务被 ROM 悄悄停掉、或被结束提醒的原生接收器
  /// 收掉时，它说了算。
  Future<bool> get isRunning async {
    if (kIsWeb || _platformUnavailable) return false;
    try {
      return await FlutterForegroundTask.isRunningService;
    } on MissingPluginException {
      _platformUnavailable = true;
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 首次启动服务（或已启动时更新）。返回服务是否处于运行态。
  ///
  /// [title] 只作为**初始**文案：服务起来后，后台 isolate 每秒会自行重算。
  Future<bool> start({
    required String presetName,
    required String title,
    required String text,
    required List<ForegroundPhase> phases,
    required String status,
    int pausedRemainingMs = 0,
  }) async {
    if (kIsWeb || _platformUnavailable) return false;
    final Map<String, dynamic> state = _statePayload(
      presetName: presetName,
      phases: phases,
      status: status,
      pausedRemainingMs: pausedRemainingMs,
    );
    final String payload = jsonEncode(state);

    try {
      if (await FlutterForegroundTask.isRunningService) {
        await _pushToTask(payload);
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
        );
        return true;
      }

      final ServiceRequestResult result =
          await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        // specialUse：没有运行时前置条件，也没有 Android 15 对 dataSync 的
        // 6 小时上限，是计时器类应用最合适（也可能是唯一不别扭）的类型。
        serviceTypes: const <ForegroundServiceTypes>[
          ForegroundServiceTypes.specialUse,
        ],
        notificationTitle: title,
        notificationText: text,
        notificationIcon: const NotificationIcon(
          metaDataName: kForegroundIconMetaData,
        ),
        callback: setbeatForegroundEntryPoint,
      );

      // 状态必须在服务起来之后才灌：先发会因为后台 isolate 还没就绪而丢失
      await _pushToTask(payload);
      return result is ServiceRequestSuccess;
    } on MissingPluginException {
      // 宿主没有注册原生实现。判一次就够了，之后全部短路。
      _platformUnavailable = true;
      return false;
    } catch (e) {
      debugPrint('[fgs] start failed: $e');
      return false;
    }
  }

  /// 停止常驻通知。未启动时静默返回。
  Future<void> stop() async {
    if (kIsWeb || _platformUnavailable) return;
    try {
      if (!await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.stopService();
    } catch (_) {
      // 停止失败最坏情况是留一条常驻通知，用户下拉划掉即可
    }
  }

  /// 注册来自后台 isolate 的消息回调，返回该回调以便注销。
  ///
  /// 目前只有 `need-sync`（后台发现时间轴用尽，请主 isolate 补一份）。
  /// 主 isolate 若也处于冻结状态，这条消息会丢，属于可接受的降级：
  /// 用户点一下通知进 App，全量状态立刻恢复。
  ///
  /// **必须注销**：插件的回调注册在一个静态列表里，不注销就会随着
  /// provider 重建不断累积，最终每次消息触发 N 次同步。
  static DataCallback addSyncRequestListener(Future<void> Function() listener) {
    void callback(Object data) {
      final Object? parsed = data is String ? _tryDecode(data) : data;
      if (parsed is Map && parsed['type'] == 'need-sync') {
        unawaited(listener());
      }
    }

    FlutterForegroundTask.addTaskDataCallback(callback);
    return callback;
  }

  /// 注销 [addSyncRequestListener] 返回的回调。
  static void removeSyncRequestListener(DataCallback callback) {
    FlutterForegroundTask.removeTaskDataCallback(callback);
  }

  Map<String, dynamic> _statePayload({
    required String presetName,
    required List<ForegroundPhase> phases,
    required String status,
    required int pausedRemainingMs,
  }) =>
      <String, dynamic>{
        'type': 'sync',
        'presetName': presetName,
        'status': status,
        'pausedRemainingMs': pausedRemainingMs,
        'phases': phases.map((ForegroundPhase p) => p.toJson()).toList(),
      };

  Future<void> _pushToTask(String payload) async {
    // 双写：一份走端口给活着的后台 isolate，一份落盘给「服务被系统重启后
    // 冷启动出来的」那个新 isolate —— 后者拿不到端口里历史消息。
    FlutterForegroundTask.sendDataToTask(payload);
    try {
      await FlutterForegroundTask.saveData(
        key: kForegroundStateKey,
        value: payload,
      );
    } catch (_) {}
  }
}

/// 常驻通知的文案推导。**主 isolate 与后台 isolate 共用这一份**。
///
/// [nowMs] 由调用方给出：主 isolate 传当前墙钟，后台 isolate 传 tick 时间戳。
({String title, String text}) describeForeground({
  required String presetName,
  required String status,
  required List<ForegroundPhase> phases,
  required int nowMs,
  int pausedRemainingMs = 0,
}) {
  final ForegroundPhase? current = _currentPhase(phases, nowMs);

  switch (status) {
    case 'paused':
      final String label = current?.label ?? (presetName.isEmpty ? 'SetBeat' : presetName);
      return (
        title: '已暂停 · $label',
        text: '剩余 ${formatTime((pausedRemainingMs / 1000).ceil())}',
      );
    case 'finished':
      return (title: '训练完成', text: '本轮训练已全部结束，辛苦了');
    case 'idle':
      return (title: presetName.isEmpty ? 'SetBeat' : presetName, text: '待机中');
    default:
      if (current == null) {
        // 时间轴走完了但状态还是 running：主 isolate 多半被冻结了。
        return (
          title: presetName.isEmpty ? 'SetBeat' : presetName,
          text: '时间轴已走完…',
        );
      }
      final int remainMs = current.endWallMs - nowMs;
      final int seconds = remainMs <= 0 ? 0 : (remainMs / 1000).ceil();
      return (
        title: current.totalRounds > 1
            ? '${current.label} · 第 ${current.round}/${current.totalRounds} 轮'
            : current.label,
        text: '剩余 ${formatTime(seconds)}',
      );
  }
}

/// 当前所处的段位：时间轴上第一个「尚未结束」的项。
/// 时间轴按起始时间升序，线性扫一遍即可。
ForegroundPhase? _currentPhase(List<ForegroundPhase> phases, int nowMs) {
  for (final ForegroundPhase p in phases) {
    if (p.endWallMs > nowMs) return p;
  }
  return null;
}

/// manifest 里 `<meta-data>` 的名字，其值是通知小图标的 drawable 资源 id。
///
/// 必须是纯白单色剪影：Android 会把它当遮罩自行着色，彩图会糊成一坨色块。
const String kForegroundIconMetaData =
    'com.pravera.flutter_foreground_task.notification_icon';

/// 后台 isolate 落盘状态的键
const String kForegroundStateKey = 'setbeat_fgs_state';

/// 后台 isolate 的入口。
///
/// **必须是顶层函数且标注 `@pragma('vm:entry-point')`** ——
/// 否则 release 构建的 tree-shaking 会把它当死代码摇掉，
/// 表现为「debug 正常、release 服务根本起不来」。
@pragma('vm:entry-point')
void setbeatForegroundEntryPoint() {
  FlutterForegroundTask.setTaskHandler(SetBeatForegroundTaskHandler());
}

/// 运行在独立 isolate 里的任务处理器。
///
/// 这里**不能碰任何主 isolate 的对象**（引擎、Riverpod、仓库）。
/// 它能拿到的只有两样：系统给的时间戳，和主 isolate 通过端口推来的 JSON。
class SetBeatForegroundTaskHandler extends TaskHandler {
  List<ForegroundPhase> _phases = const <ForegroundPhase>[];
  String _presetName = '';
  String _status = 'idle';
  int _pausedRemainingMs = 0;

  /// 上一次真正写进通知的文案，用于抑制无变化的重绘。
  String _lastTitle = '';
  String _lastText = '';

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // starter == TaskStarter.system 说明服务是被系统拉起（而非用户点了开始），
    // 此时 isolate 内字段全是空的，必须从落盘状态恢复，
    // 否则常驻通知会停在「正在计时…」这种无信息量的占位文案上。
    if (starter != TaskStarter.system) return;
    try {
      final String? saved =
          await FlutterForegroundTask.getData<String>(key: kForegroundStateKey);
      if (saved == null || saved.isEmpty) return;
      _applyState(_tryDecode(saved));
      _render(timestamp.millisecondsSinceEpoch);
    } catch (_) {
      // 恢复失败就保持空白状态，由主 isolate 下次 sync 覆盖
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _render(timestamp.millisecondsSinceEpoch);
  }

  @override
  void onReceiveData(Object data) {
    final Object? parsed = data is String ? _tryDecode(data) : data;
    if (parsed is! Map) return;
    _applyState(parsed);
    // 状态变了就允许重绘一次
    _lastTitle = '';
    _lastText = '';
    _render(DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    try {
      await FlutterForegroundTask.removeData(key: kForegroundStateKey);
    } catch (_) {}
  }

  @override
  void onNotificationPressed() {
    // 点通知回到 App。这条完全走系统路径，不依赖主 isolate 是否活着。
    FlutterForegroundTask.launchApp();
  }

  // ------------------------------------------------------------------ 内部

  void _applyState(Object? raw) {
    if (raw is! Map) return;
    _presetName = raw['presetName'] is String ? raw['presetName'] as String : '';
    _status = raw['status'] is String ? raw['status'] as String : 'idle';
    _pausedRemainingMs =
        raw['pausedRemainingMs'] is int ? raw['pausedRemainingMs'] as int : 0;

    final Object? phases = raw['phases'];
    if (phases is! List) {
      _phases = const <ForegroundPhase>[];
      return;
    }
    final List<ForegroundPhase> parsed = <ForegroundPhase>[];
    for (final Object? item in phases) {
      if (item is! Map) continue;
      final ForegroundPhase? p =
          ForegroundPhase.fromJson(Map<String, dynamic>.from(item));
      if (p != null) parsed.add(p);
    }
    _phases = parsed;
  }

  void _render(int nowMs) {
    if (_status == 'idle') return;

    final ({String title, String text}) d = describeForeground(
      presetName: _presetName,
      status: _status,
      phases: _phases,
      nowMs: nowMs,
      pausedRemainingMs: _pausedRemainingMs,
    );

    if (!_publish(d.title, d.text)) return;

    // 时间轴用尽（且不是暂停/完成）说明主 isolate 被冻结了，
    // 喊一声让它有机会补数据。只在文案变化的那一次喊，否则就是每秒一次
    // 的无用广播。
    if (_status == 'running' && _currentPhase(_phases, nowMs) == null) {
      _requestSync();
    }
  }

  /// 只在文案真的变化时才写系统通知。返回 true 表示这次真的更新了通知。
  bool _publish(String title, String text) {
    if (title == _lastTitle && text == _lastText) return false;
    _lastTitle = title;
    _lastText = text;
    // 不 await：onRepeatEvent 是 void；同一 id 的通知更新是覆盖式的，
    // 即使上一次还没回来也不会堆积。
    unawaited(
      FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      ).catchError((Object _) => const ServiceRequestFailure(error: 'ignored')),
    );
    return true;
  }

  void _requestSync() {
    try {
      FlutterForegroundTask.sendDataToMain(
        <String, dynamic>{'type': 'need-sync'},
      );
    } catch (_) {}
  }
}

Object? _tryDecode(String raw) {
  try {
    return jsonDecode(raw);
  } catch (_) {
    return null;
  }
}
