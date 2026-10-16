import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setbeat_flutter/engine/timer_engine.dart';
import 'package:setbeat_flutter/models/time_card.dart';
import 'package:setbeat_flutter/services/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 排期层验证。
///
/// 排期与投递已迁移到原生 `SetBeatAlerts`（原因见 NotificationService 的类注释：
/// flutter_local_notifications 的通知 id 同时是闹钟 requestCode，无法做到
/// 「多条提醒共用一个通知槽位」）。所以这里断言的对象从插件的 `zonedSchedule`
/// 换成了我们自己的 `scheduleTimerAlerts` 载荷。
///
/// `flutter_local_notifications` 仍然保留，但只剩权限探测一条用途 ——
/// 它的方法通道照样要 mock，否则权限相关断言会拿到 null。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  debugDefaultTargetPlatformOverride = TargetPlatform.android;

  // 测试环境没有插件注册器，平台实例是 late 字段，必须手工注入
  FlutterLocalNotificationsPlatform.instance =
      AndroidFlutterLocalNotificationsPlugin();

  const String flnChannel = 'dexterous.com/flutter/local_notifications';
  const String nativeChannel = 'setbeat/platform';

  final List<MethodCall> nativeCalls = <MethodCall>[];
  final List<MethodCall> flnCalls = <MethodCall>[];

  /// 原生侧回给 Dart 的「系统里真实存在的闹钟数」
  int armedCount = 0;

  /// scheduleTimerAlerts 的返回值。false 用来模拟系统拒排。
  bool nativeScheduleOk = true;

  List<Map<String, dynamic>> lastScheduledPayload() {
    final MethodCall call = nativeCalls.lastWhere(
      (MethodCall c) => c.method == 'scheduleTimerAlerts',
    );
    final Map<Object?, Object?> args =
        call.arguments as Map<Object?, Object?>;
    return (jsonDecode(args['alerts']! as String) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<Object?>? flnHandler(MethodCall call) {
    flnCalls.add(call);
    switch (call.method) {
      case 'initialize':
        return Future<bool>.value(true);
      case 'createNotificationChannel':
      case 'cancelAllPendingNotifications':
        return Future<void>.value();
      case 'requestNotificationsPermission':
      case 'requestExactAlarmsPermission':
        return Future<bool>.value(true);
      case 'areNotificationsEnabled':
        return Future<bool>.value(true);
      case 'canScheduleExactNotifications':
        return Future<bool>.value(true);
      default:
        return Future<Object?>.value();
    }
  }

  Future<Object?>? nativeHandler(MethodCall call) {
    nativeCalls.add(call);
    switch (call.method) {
      case 'scheduleTimerAlerts':
        return Future<bool>.value(nativeScheduleOk);
      case 'armedAlertCount':
        return Future<int>.value(armedCount);
      case 'showTestAlert':
        return Future<bool>.value(nativeScheduleOk);
      case 'cancelTimerAlerts':
      case 'cancelLegacyAlerts':
        return Future<void>.value();
      case 'getTimeZone':
        return Future<String>.value('UTC');
      default:
        return Future<Object?>.value();
    }
  }

  setUp(() {
    nativeCalls.clear();
    flnCalls.clear();
    armedCount = 0;
    nativeScheduleOk = true;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(flnChannel), flnHandler);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(nativeChannel), nativeHandler);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(flnChannel), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(nativeChannel), null);
    debugDefaultTargetPlatformOverride = null;
  });

  List<UpcomingBoundary> boundaries() {
    // 3 张卡（60s/15s/60s）单循环：2 个切换点 + 1 个结束点
    final List<TimeCard> cards = <TimeCard>[
      const TimeCard(id: 'a', label: '训练', duration: 60, color: '#ff6b35'),
      const TimeCard(id: 'b', label: '休息', duration: 15, color: '#4ecdc4'),
      const TimeCard(id: 'c', label: '训练', duration: 60, color: '#ff6b35'),
    ];
    final int now = DateTime.now().millisecondsSinceEpoch;
    return <UpcomingBoundary>[
      UpcomingBoundary(
          isFinal: false,
          position: 1,
          card: cards[1],
          round: 1,
          totalRounds: 1,
          inMs: 60000,
          atWallMs: now + 60000),
      UpcomingBoundary(
          isFinal: false,
          position: 2,
          card: cards[2],
          round: 1,
          totalRounds: 1,
          inMs: 75000,
          atWallMs: now + 75000),
      UpcomingBoundary(
          isFinal: true,
          position: 2,
          card: cards[2],
          round: 1,
          totalRounds: 1,
          inMs: 135000,
          atWallMs: now + 135000),
    ];
  }

  test('排期：每个边界一条，结束点标题正确', () async {
    final NotificationService svc = NotificationService();
    await svc.scheduleAlerts('测试方案', boundaries());

    final List<Map<String, dynamic>> alerts = lastScheduledPayload();
    expect(alerts, hasLength(3));
    expect(alerts[0]['title'], '休息 · 第 1/1 轮');
    expect(alerts[1]['title'], '训练 · 第 1/1 轮');
    expect(alerts[2]['title'], '训练完成');
    expect(alerts[2]['body'], '本轮训练已全部完成，辛苦了');
    // seq 决定闹钟的 requestCode，必须唯一 —— 撞了就会互相覆盖
    expect(alerts.map((Map<String, dynamic> a) => a['seq']).toSet(), hasLength(3));
    expect(svc.lastScheduleError, isNull);
  });

  test('已经过去的边界不下发 —— 否则系统会对过去时间立刻触发，几条一起弹', () async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final List<UpcomingBoundary> past = <UpcomingBoundary>[
      UpcomingBoundary(
          isFinal: false,
          position: 1,
          card: const TimeCard(
              id: 'b', label: '休息', duration: 15, color: '#4ecdc4'),
          round: 1,
          totalRounds: 1,
          inMs: -5000,
          atWallMs: now - 5000),
      UpcomingBoundary(
          isFinal: true,
          position: 2,
          card: const TimeCard(
              id: 'c', label: '训练', duration: 60, color: '#ff6b35'),
          round: 1,
          totalRounds: 1,
          inMs: 30000,
          atWallMs: now + 30000),
    ];

    final NotificationService svc = NotificationService();
    await svc.scheduleAlerts('测试方案', past);

    final List<Map<String, dynamic>> alerts = lastScheduledPayload();
    expect(alerts, hasLength(1));
    expect(alerts.single['title'], '训练完成');
    expect((alerts.single['atMs'] as int) > now, isTrue);
  });

  test('没有任何未来边界时只清空，不发排期请求', () async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final NotificationService svc = NotificationService();
    await svc.scheduleAlerts('测试方案', <UpcomingBoundary>[
      UpcomingBoundary(
          isFinal: true,
          position: 0,
          card: const TimeCard(
              id: 'a', label: '训练', duration: 60, color: '#ff6b35'),
          round: 1,
          totalRounds: 1,
          inMs: -1000,
          atWallMs: now - 1000),
    ]);

    expect(
      nativeCalls.any((MethodCall c) => c.method == 'scheduleTimerAlerts'),
      isFalse,
    );
    expect(
      nativeCalls.where((MethodCall c) => c.method == 'cancelTimerAlerts'),
      isNotEmpty,
    );
    expect(svc.lastScheduleError, isNull);
  });

  test('原生拒排时记录到 lastScheduleError，不静默消失', () async {
    nativeScheduleOk = false;
    final NotificationService svc = NotificationService();
    await svc.scheduleAlerts('测试方案', boundaries());

    expect(svc.lastScheduleError, isNotNull);
  });

  test('已排期条数取自系统真实闹钟数，而不是本地记录', () async {
    // 本地明明排了 3 条，但系统里一个都不剩（被 force-stop 清空的场景）——
    // 这正是旧实现给出假阳性、把排查带偏的地方。
    armedCount = 0;
    final NotificationService svc = NotificationService();
    await svc.scheduleAlerts('测试方案', boundaries());

    expect(await svc.pendingNotificationCount(), 0);

    armedCount = 3;
    expect(await svc.pendingNotificationCount(), 3);
  });

  test('精确闹钟被拒时不静默丢排期，仍会下发', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(flnChannel),
            (MethodCall call) async {
      if (call.method == 'canScheduleExactNotifications') {
        return Future<bool>.value(false);
      }
      return flnHandler(call);
    });

    final NotificationService svc = NotificationService();
    await svc.ensurePermissions();
    await svc.scheduleAlerts('测试方案', boundaries());

    expect(svc.exactAllowed, isFalse);
    // 关键：权限不足只是让提醒「可能不准点」，绝不能变成「一条都不排」
    expect(lastScheduledPayload(), hasLength(3));
  });

  test('取消排期走原生通道，不再依赖插件的本地缓存', () async {
    final NotificationService svc = NotificationService();
    await svc.cancelAll();

    expect(
      nativeCalls.any((MethodCall c) => c.method == 'cancelTimerAlerts'),
      isTrue,
    );
    expect(
      flnCalls.any((MethodCall c) => c.method == 'cancelAllPendingNotifications'),
      isFalse,
    );
  });

  test('测试提醒走原生通道', () async {
    final NotificationService svc = NotificationService();
    expect(await svc.showTestAlert(), isTrue);
    expect(
      nativeCalls.any((MethodCall c) => c.method == 'showTestAlert'),
      isTrue,
    );
  });

  test('初始化时清理旧版本用插件排下的残留闹钟', () async {
    // 旧版本把提醒交给插件排期，升级后那些闹钟仍真实存在于系统中。
    // 不收掉的话会在之后某个时刻补发，表现为「好几条通知一起弹」。
    // 两条路一起走：插件的缓存路径 + 原生的探测路径。
    final NotificationService svc = NotificationService();
    await svc.init();

    expect(
      flnCalls.any((MethodCall c) => c.method == 'cancelAllPendingNotifications'),
      isTrue,
    );
    expect(
      nativeCalls.any((MethodCall c) => c.method == 'cancelLegacyAlerts'),
      isTrue,
    );
  });

  test('只读自检不触发系统授权请求', () async {
    final NotificationService svc = NotificationService();
    final AlarmCapability cap = await svc.checkCapability();

    expect(cap.initialized, isTrue);
    expect(cap.notificationsAllowed, isTrue);
    expect(cap.exactAlarmsAllowed, isTrue);
    // 关键：自检只读，不能弹授权对话框
    expect(
      flnCalls.any((MethodCall c) =>
          c.method == 'requestNotificationsPermission' ||
          c.method == 'requestExactAlarmsPermission'),
      isFalse,
    );
  });
}
