import 'dart:ui' show Color;

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
/// 全部用 `zonedSchedule` 交给系统 AlarmManager。到点由**操作系统**触发通知，
/// 与 App 进程是否存活无关——息屏、退后台、甚至杀掉进程都能弹。
///
/// 这才是计时器类应用的正解：不要指望自己的进程活着，要指望系统闹钟准时。
class NotificationService {
  static const String _channelId = 'setbeat_timer_alerts';
  static const String _channelName = '计时提醒';
  static const String _channelDescription = '训练计时器的阶段切换与结束提醒';

  /// 通知 id 的固定基数。排期槽位 = 基数 + 序号，
  /// 固定基数让「取消本次计时的全部提醒」变成一次 cancelAllPendingNotifications。
  static const int _baseId = 0x5E7B0000;

  /// 「提醒测试」专用 id，与计时排期互不干扰
  static const int _testAlertId = _baseId + 999;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool get isReady => _initialized;

  /// 精确闹钟是否可用。不可用时自动降级为 inexact（仍会弹出，最多延迟几分钟），
  /// 而不是静默不排。
  bool _exactAllowed = true;
  bool get exactAllowed => _exactAllowed;
  AndroidScheduleMode get _scheduleMode => _exactAllowed
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

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

  /// 发一条 3 秒后的测试提醒，走与真实计时完全相同的排期路径。
  ///
  /// 这是「弹不出来」问题的终极自证手段：能看到它 → 链路正常，
  /// 问题在计时逻辑；看不到 → 问题在系统通知设置。
  Future<bool> showTestAlert() async {
    await init();
    if (kIsWeb) return false;
    lastScheduleError = null;
    try {
      final tz.TZDateTime when =
          tz.TZDateTime.now(tz.local).add(const Duration(seconds: 3));
      await _plugin.zonedSchedule(
        id: _testAlertId,
        title: '提醒测试',
        body: '看到这条说明系统提醒链路正常',
        scheduledDate: when,
        notificationDetails: NotificationDetails(android: _alertDetails()),
        androidScheduleMode: _scheduleMode,
        payload: 'test',
      );
      return true;
    } catch (e) {
      lastScheduleError = e.toString();
      return false;
    }
  }

  /// 取消测试提醒
  Future<void> cancelTestAlert() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(id: _testAlertId);
    } catch (_) {}
  }

  /// 把一次计时展开成系统级排期。
  ///
  /// [boundaries] 来自 `TimerEngine.upcomingBoundaries()`，
  /// 已按时间排序、已裁剪数量且保证包含结束点。
  ///
  /// 失败不抛出（不打断计时），错误记录到 [lastScheduleError]，
  /// 由 UI 结合 [pendingNotificationCount] 展示诊断信息。
  Future<void> scheduleAlerts(
    String presetName,
    List<UpcomingBoundary> boundaries,
  ) async {
    // ignore: avoid_print
    print('[restore-probe] scheduleAlerts begin');
    await init();
    // ignore: avoid_print
    print('[restore-probe] scheduleAlerts init done');
    lastScheduleError = null;
    if (kIsWeb || boundaries.isEmpty) return;

    try {
      // 先清掉上一轮的排期，避免残留
      await cancelAll();

      final NotificationDetails details = NotificationDetails(
        android: _alertDetails(),
      );
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

      int slot = 0;
      for (final UpcomingBoundary b in boundaries) {
        final tz.TZDateTime when = tz.TZDateTime.fromMillisecondsSinceEpoch(
            tz.local, b.atWallMs);
        // 已经过去的边界（比如恢复后立刻排期时）直接跳过
        if (!when.isAfter(now)) continue;

        await _plugin.zonedSchedule(
          id: _baseId + slot,
          title: _titleFor(presetName, b),
          body: _bodyFor(b),
          scheduledDate: when,
          notificationDetails: details,
          // 精确闹钟不可用时降级为 inexact：仍会弹出，最多延迟几分钟，
          // 远好于因为权限被拒而整条提醒链路静默失效。
          androidScheduleMode: _scheduleMode,
          payload: b.isFinal ? 'finish' : 'switch:${b.position}',
        );
        slot++;
      }
    } catch (e) {
      lastScheduleError = e.toString();
    }
    // ignore: avoid_print
    print('[restore-probe] scheduleAlerts end');
  }

  /// 当前待触发的排期数量。UI 用它确认排期是否真的写进了系统。
  Future<int> pendingNotificationCount() async {
    if (kIsWeb) return 0;
    try {
      return (await _plugin.pendingNotificationRequests()).length;
    } catch (_) {
      return -1;
    }
  }

  /// 取消全部待触发的提醒。暂停 / 重置 / 离开计时页时调用。
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancelAllPendingNotifications();
    } catch (_) {}
  }

  // ------------------------------------------------------------------ 内部

  AndroidNotificationDetails _alertDetails() => AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        playSound: true,
        enableVibration: true,
        // 注意类型是 Int64List 而不是 List<int>
        vibrationPattern: Int64List.fromList(<int>[0, 400, 150, 400]),
        enableLights: true,
        ledColor: const Color(0xFFFF6B35),
        // 开了呼吸灯就必须同时给亮灭时长，否则插件在 Android 8 以下
        // 校验路径抛 invalid_led_details，整个排期失败（真机已踩）
        ledOnMs: 400,
        ledOffMs: 150,
        color: const Color(0xFFFF6B35),
        autoCancel: true,
        ticker: 'SetBeat 计时提醒',
      );

  String _titleFor(String presetName, UpcomingBoundary b) {
    if (b.isFinal) return '训练完成';
    return '${b.card.label} · 第 ${b.round}/${b.totalRounds} 轮';
  }

  String _bodyFor(UpcomingBoundary b) {
    if (b.isFinal) return '本轮训练已全部完成，辛苦了';
    return '切换到 ${b.card.label}（${formatDurationShort(b.card.duration)}）';
  }
}
