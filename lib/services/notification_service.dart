import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../engine/timer_engine.dart';
import '../utils/format.dart';
import 'platform_bridge.dart';

/// 提醒能力自检结果，UI 据此引导用户去系统设置补授权。
class AlarmCapability {
  final bool initialized;

  /// 是否允许弹出通知（Android 13+ 的运行时权限）
  final bool notificationsAllowed;

  /// 是否允许精确闹钟（决定提醒能不能准点触发）
  final bool exactAlarmsAllowed;

  const AlarmCapability({
    required this.initialized,
    required this.notificationsAllowed,
    required this.exactAlarmsAllowed,
  });

  bool get fullyCapable =>
      initialized && notificationsAllowed && exactAlarmsAllowed;

  /// 给用户看的一句话诊断，用于首页顶部提示条
  String? get problemHint {
    if (!initialized) return '提醒服务初始化失败';
    if (!notificationsAllowed) return '通知权限未开启，计时结束将无法提醒';
    if (!exactAlarmsAllowed) return '未授予「闹钟和提醒」权限，提醒可能不准点';
    return null;
  }
}

/// 提醒服务 —— 本次改造的重点。
///
/// ## 为什么原版的提醒弹不出来
///
/// 原版用 `@capacitor/local-notifications`，但 `AndroidManifest.xml` 只声明了
/// `INTERNET`：
///   1. 没有 `POST_NOTIFICATIONS` —— Android 13+ 不申请运行时权限，notify() 直接静默失败；
///   2. 没有 `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` —— 精确闹钟全部被系统合并、推迟；
///   3. 没有注册 ScheduledNotificationReceiver —— 即使排期成功，到点也没人接收。
///
/// 于是原版最终放弃通知、改成「结束时播 5 秒音乐」——但 App 退到后台后
/// WebView 的音频同样会被挂起，等于提醒彻底失效。
///
/// ## Flutter 版的做法
///
/// **排期制**：开始计时的瞬间，就把后续每一个段位切换点和结束点
/// 全部交给系统 AlarmManager。到点由**操作系统**触发通知，
/// 与 App 进程是否存活无关——息屏、退后台、甚至杀掉进程都能弹。
///
/// 这才是计时器类应用的正解：不要指望自己的进程活着，要指望系统闹钟准时。
///
/// ## 为什么排期与投递改成了原生实现（`SetBeatAlerts`）
///
/// 原先走 `flutter_local_notifications` 的 `zonedSchedule`。但那个插件的
/// **通知 id 同时就是 AlarmManager 的 requestCode**，而它构造的 Intent 里
/// 除了 extras 没有任何唯一标识。于是：
///
///   · 想要「多条提醒共用一个通知槽位、新的顶掉旧的」→ 必须传同一个 id
///     → requestCode 相同 + Intent filterEquals 相同 → PendingIntent 被判等
///     → AlarmManager 只保留最后一个闹钟，**前面的提醒全部静默丢失**。
///
/// 「一个槽位」和「每条都触发」在它的公开 API 下互斥，只能自己把
/// 通知槽位与闹钟 requestCode 解耦。顺带还修掉了另一个隐患：插件靠本地缓存
/// 做取消，缓存失准（反复重装 / force-stop）时旧闹钟会赖在系统里，之后
/// 被 Doze 解除后的补发一次性全投递 —— 这就是「好几条通知一起弹」的来源。
///
/// 现在这个类只负责三件事：**权限、文案、以及把排期翻译成原生调用**。
class NotificationService {
  static const String _channelId = 'setbeat_timer_alerts';
  static const String _channelName = '计时提醒';
  static const String _channelDescription = '训练计时器的阶段切换与结束提醒';

  /// 单次排期的段位上限。与原生 `SetBeatAlerts.MAX_ALERTS` 保持一致 ——
  /// 超出部分原生会丢弃，这里先裁掉以免产生「排了但没生效」的错觉。
  static const int _maxAlerts = 64;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool get isReady => _initialized;

  /// 精确闹钟是否可用。不可用时原生侧自动降级（仍会弹出，最多延迟几分钟），
  /// 而不是静默不排。这里保留一份是为了让 UI 能显示诊断信息。
  bool _exactAllowed = true;
  bool get exactAllowed => _exactAllowed;

  /// 最近一次排期失败的错误（供 UI 展示诊断信息）
  String? lastScheduleError;

  /// 初始化：时区 + 插件 + 通知渠道。可重复调用。
  ///
  /// 整体 try/catch：个别 OEM 的通知实现可能有兼容性问题，
  /// 初始化失败只意味着「提醒不可用」，绝不能拖垮 App 启动。
  Future<void> init() async {
    if (_initialized) return;

    // Web 目标仅用于开发期快速预览 UI，提醒能力本就不可用
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    try {
      // zonedSchedule 需要已初始化的时区数据库
      tzdata.initializeTimeZones();
      final String zoneName = await PlatformBridge.getTimeZone();
      try {
        tz.setLocalLocation(tz.getLocation(zoneName));
      } catch (_) {
        // 时区名非法就退回 UTC：提醒时间会偏移，但绝不能因此崩溃
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      // 小图标必须是纯白单色（Android 会自行着色），彩色图会被渲染成一坨色块
      const AndroidInitializationSettings android =
          AndroidInitializationSettings('ic_stat_setbeat');
      const InitializationSettings settings =
          InitializationSettings(android: android);
      await _plugin.initialize(settings: settings);

      // 显式建渠道并设为最高重要性 —— 这是「悬浮式提醒（heads-up）」的前提。
      // 低于 IMPORTANCE_HIGH 的渠道只会静静躺在通知栏里，用户根本注意不到。
      // 原生 `SetBeatAlerts.ensureChannel` 会建同名渠道，两边是幂等的；
      // 渠道属性创建后不可改，所以老用户既有的重要性/铃声选择会被保留。
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            vibrationPattern: Int64List.fromList(<int>[0, 400, 150, 400]),
          ));

      // 升级期清理：旧版本用插件排下的闹钟此刻仍真实存在于系统中，
      // 到点照样会弹。两条路一起收 —— 插件的缓存路径，加原生的探测路径
      //（缓存失准时只有后者管用）。
      await _plugin.cancelAllPendingNotifications();
      await PlatformBridge.cancelLegacyAlerts();

      _initialized = true;
    } catch (_) {
      _initialized = true; // 标记为已尝试，避免反复重试
    }
  }

  /// 检查并请求提醒所需权限。
  ///
  /// Android 13+ 会在系统弹窗里问用户；Android 12 的精确闹钟会跳转系统设置页。
  /// 用户拒绝不抛异常，只反映在返回值里，由 UI 决定是否提示。
  Future<AlarmCapability> ensurePermissions() async {
    await init();
    // Web 目标仅用于开发期快速预览 UI，提醒能力本就不可用。
    // 返回「无问题」以免 UI 弹出无意义的权限提示横幅。
    if (kIsWeb) {
      return const AlarmCapability(
          initialized: true,
          notificationsAllowed: true,
          exactAlarmsAllowed: true);
    }

    final AndroidFlutterLocalNotificationsPlugin? impl =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (impl == null) {
      return const AlarmCapability(
          initialized: false,
          notificationsAllowed: false,
          exactAlarmsAllowed: false);
    }

    try {
      // 请求不存在的权限在低版本上是 no-op，返回 true
      await impl.requestNotificationsPermission();

      final bool? notifications = await impl.areNotificationsEnabled();
      bool? exact;
      try {
        await impl.requestExactAlarmsPermission();
        exact = await impl.canScheduleExactNotifications();
      } catch (_) {
        // Android <12 没有「闹钟和提醒」开关，接口可能不存在：按可用处理
        exact = true;
      }
      _exactAllowed = exact ?? true;
      return AlarmCapability(
        initialized: true,
        notificationsAllowed: notifications ?? true,
        exactAlarmsAllowed: _exactAllowed,
      );
    } catch (_) {
      // 个别 OEM 的权限接口可能抛错：按「未授权」处理，UI 会给出提示
      _exactAllowed = false;
      return const AlarmCapability(
          initialized: true,
          notificationsAllowed: false,
          exactAlarmsAllowed: false);
    }
  }

  /// 只读地检查提醒能力（不弹任何系统授权对话框），供「提醒自检」面板使用。
  Future<AlarmCapability> checkCapability() async {
    await init();
    if (kIsWeb) {
      return const AlarmCapability(
          initialized: true,
          notificationsAllowed: false,
          exactAlarmsAllowed: false);
    }
    final AndroidFlutterLocalNotificationsPlugin? impl =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (impl == null) {
      return const AlarmCapability(
          initialized: false,
          notificationsAllowed: false,
          exactAlarmsAllowed: false);
    }
    try {
      final bool? notifications = await impl.areNotificationsEnabled();
      final bool? exact = await impl.canScheduleExactNotifications();
      _exactAllowed = exact ?? true;
      return AlarmCapability(
        initialized: true,
        notificationsAllowed: notifications ?? true,
        exactAlarmsAllowed: _exactAllowed,
      );
    } catch (_) {
      return const AlarmCapability(
          initialized: true,
          notificationsAllowed: false,
          exactAlarmsAllowed: false);
    }
  }

  /// 只读地探测系统是否真的允许精确闹钟（不弹任何对话框）。
  ///
  /// 存在的意义：`_exactAllowed` 的初值是 true，若设备实际没授权，
  /// 首轮排期必然整批失败、被 catch 吞成一条不剩。排期前先问一次系统，
  /// 就能把那个"必然失败的首轮"消灭掉。
  ///
  /// 注意 Android <12 没有这个开关，接口返回 null —— 此时保持原判断。
  Future<void> primeExactAlarmCapability() async {
    if (kIsWeb) return;
    try {
      final AndroidFlutterLocalNotificationsPlugin? impl =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final bool? can = await impl?.canScheduleExactNotifications();
      if (can != null) _exactAllowed = can;
    } catch (_) {
      // 探测失败不改判断，交给排期路径的降级重试兜底
    }
  }

  /// 发一条 3 秒后的测试提醒，走与真实计时**完全相同**的原生排期与投递路径。
  ///
  /// 这是「弹不出来」问题的终极自证手段：能看到它 → 链路正常，
  /// 问题在计时逻辑；看不到 → 问题在系统通知设置或后台策略。
  ///
  /// 测试提醒用独立的通知槽位与 requestCode，既不会顶掉真实提醒，
  /// 也不会被「取消全部排期」顺手清掉。3 秒后自动弹，无需手动收尾。
  Future<bool> showTestAlert() async {
    await init();
    if (kIsWeb) return false;
    lastScheduleError = null;
    final bool ok = await PlatformBridge.showTestAlert();
    if (!ok) lastScheduleError = '原生排期失败（检查通知权限）';
    return ok;
  }

  /// 把一次计时展开成系统级排期。
  ///
  /// [boundaries] 来自 `TimerEngine.upcomingBoundaries()`，
  /// 已按时间排序、已裁剪数量且保证包含结束点。
  ///
  /// 失败不抛出（不打断计时），错误记录到 [lastScheduleError]，
  /// 由 UI 结合 [pendingNotificationCount] 展示诊断信息。
  ///
  /// 语义是「**整体替换**」：原生侧进来先无条件清空再排，所以不存在
  /// 「重复调用导致叠加」的可能。调用方可以放心地在段位切换、暂停恢复、
  /// 跨进程恢复等各处反复调用。
  Future<void> scheduleAlerts(
    String presetName,
    List<UpcomingBoundary> boundaries,
  ) async {
    await init();
    lastScheduleError = null;
    if (kIsWeb) return;

    // 排期前先问系统「精确闹钟到底给不给」，让 UI 能显示准确的能力状态。
    // 原生侧自己也会判断并按需降级，这里只是把状态同步过来。
    await primeExactAlarmCapability();

    final int nowMs = DateTime.now().millisecondsSinceEpoch;

    // 已经过去的边界直接不发 —— 交给系统的话它会对过去时间立刻触发，
    // 那才是真正意义上的「好几条一起弹」。
    final List<Map<String, Object>> alerts = <Map<String, Object>>[];
    int seq = 0;
    for (final UpcomingBoundary b in boundaries) {
      if (alerts.length >= _maxAlerts) break;
      if (b.atWallMs <= nowMs) continue;
      alerts.add(<String, Object>{
        // seq 决定闹钟的 requestCode，必须稳定 —— 重启后恢复靠它找回同一个闹钟
        'seq': seq,
        'atMs': b.atWallMs,
        'title': _titleFor(presetName, b),
        'body': _bodyFor(b),
        // 结束提醒投递时，原生侧会顺带停掉常驻通知。否则「训练完成」会
        // 同时出现在常驻通知和提醒通知里，看起来就是重复的两条。
        'isFinal': b.isFinal,
      });
      seq++;
    }

    if (alerts.isEmpty) {
      // 没有未来边界（比如恢复时已经跑完），清掉残留即可
      await cancelAll();
      return;
    }

    final bool ok =
        await PlatformBridge.scheduleTimerAlerts(jsonEncode(alerts));
    if (!ok) {
      lastScheduleError = '系统拒绝了提醒排期（检查通知与「闹钟和提醒」权限）';
    }
  }

  /// 系统里**真实存在**的闹钟数量。
  ///
  /// 与旧实现的根本差别：以前读的是插件自己的本地记录，应用被 force-stop
  /// 后系统清空了闹钟，它照样报出旧数字（假阳性，排查时被误导过）。
  /// 现在这个数字是逐个探测系统拿到的，说 0 就是真的没有。
  Future<int> pendingNotificationCount() async {
    if (kIsWeb) return 0;
    return PlatformBridge.armedAlertCount();
  }

  /// 取消全部待触发的提醒。暂停 / 重置 / 离开计时页时调用。
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await PlatformBridge.cancelTimerAlerts();
  }

  // ------------------------------------------------------------------ 内部

  String _titleFor(String presetName, UpcomingBoundary b) {
    if (b.isFinal) return '训练完成';
    return '${b.card.label} · 第 ${b.round}/${b.totalRounds} 轮';
  }

  String _bodyFor(UpcomingBoundary b) {
    if (b.isFinal) return '本轮训练已全部完成，辛苦了';
    return '切换到 ${b.card.label}（${formatDurationShort(b.card.duration)}）';
  }
}
