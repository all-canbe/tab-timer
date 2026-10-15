import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:setbeat_flutter/engine/timer_engine.dart';
import 'package:setbeat_flutter/models/time_card.dart';
import 'package:setbeat_flutter/services/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 排期层验证：把 flutter_local_notifications 的 Android 方法通道 mock 掉，
/// 断言「开始一次计时 → 每个段位边界 + 结束点都被写进系统排期」，
/// 以及精确闹钟权限被拒时自动降级为 inexact 而不是静默失败。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 强制走 Android 插件实现分支
  debugDefaultTargetPlatformOverride = TargetPlatform.android;

  // 测试环境没有插件注册器，平台实例是 late 字段，必须手工注入
  FlutterLocalNotificationsPlatform.instance =
      AndroidFlutterLocalNotificationsPlugin();

  const String channel = 'dexterous.com/flutter/local_notifications';
  final List<MethodCall> zonedCalls = <MethodCall>[];
  bool exactAllowed = true;

  final List<MethodCall> allCalls = <MethodCall>[];

  Future<Object?>? handler(MethodCall call) {
    allCalls.add(call);
    switch (call.method) {
      case 'initialize':
        return Future<bool>.value(true);
      case 'createNotificationChannel':
        return Future<void>.value();
      case 'requestNotificationsPermission':
      case 'requestExactAlarmsPermission':
        return Future<bool>.value(true);
      case 'areNotificationsEnabled':
        return Future<bool>.value(true);
      case 'canScheduleExactNotifications':
        return Future<bool>.value(exactAllowed);
      case 'cancelAllPendingNotifications':
        return Future<void>.value();
      case 'pendingNotificationRequests':
        return Future<List<dynamic>>.value(
          List<dynamic>.generate(zonedCalls.length, (int i) => <String, Object?>{
                'id': i,
                'title': 't$i',
              }),
        );
      case 'zonedSchedule':
        zonedCalls.add(call);
        return Future<void>.value();
      default:
        return Future<Object?>.value();
    }
  }

  setUp(() {
    zonedCalls.clear();
    allCalls.clear();
    exactAllowed = true;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel(channel), handler);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(channel), null);
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

    expect(zonedCalls.length, 3);
    expect(zonedCalls[0].arguments['title'], '休息 · 第 1/1 轮');
    expect(zonedCalls[1].arguments['title'], '训练 · 第 1/1 轮');
    expect(zonedCalls[2].arguments['title'], '训练完成');
    expect(zonedCalls[2].arguments['payload'], 'finish');
    // id 逐条递增且唯一
    final List<Object?> ids =
        zonedCalls.map((MethodCall c) => c.arguments['id']).toList();
    expect(ids.toSet().length, 3);
    expect(await svc.pendingNotificationCount(), 3);
    expect(svc.lastScheduleError, isNull);
  });

  test('精确闹钟被拒时降级为 inexact，排期不静默消失', () async {
    exactAllowed = false;
    final NotificationService svc = NotificationService();
    await svc.ensurePermissions();
    await svc.scheduleAlerts('测试方案', boundaries());

    expect(zonedCalls.length, 3);
    // scheduleMode 位于 platformSpecifics 内（插件 v22 的排布）
    final Map<Object?, Object?> specifics =
        zonedCalls[0].arguments['platformSpecifics'] as Map<Object?, Object?>;
    expect(specifics['scheduleMode'], 'inexactAllowWhileIdle');
  });

  test('平台通道抛错时记录到 lastScheduleError 而不向外抛', () async {
    // 让 zonedSchedule 抛错
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(channel),
            (MethodCall call) async {
      if (call.method == 'zonedSchedule') {
        throw PlatformException(code: 'security', message: 'no exact alarm');
      }
      return handler(call);
    });

    final NotificationService svc = NotificationService();
    await svc.scheduleAlerts('测试方案', boundaries());
    expect(svc.lastScheduleError, isNotNull);
  });

  test('开启呼吸灯必须带 ledOnMs/ledOffMs（真机 invalid_led_details 回归）', () async {
    final NotificationService svc = NotificationService();
    await svc.scheduleAlerts('测试方案', boundaries());

    // 插件 v22：android 细节平铺在 platformSpecifics 下
    final Map<Object?, Object?> details =
        zonedCalls.first.arguments['platformSpecifics'] as Map<Object?, Object?>;

    expect(details['enableLights'], true);
    // 缺了任一项，插件在 Android 8 以下校验路径抛 invalid_led_details，
    // 整个排期失败——真机已实际踩过
    expect(details['ledOnMs'], 400);
    expect(details['ledOffMs'], 150);
  });

  test('测试提醒：走与真实计时相同的排期路径，3 秒后触发', () async {
    final NotificationService svc = NotificationService();
    final DateTime before = DateTime.now();
    expect(await svc.showTestAlert(), isTrue);

    expect(zonedCalls, hasLength(1));
    expect(zonedCalls.single.arguments['title'], '提醒测试');
    expect(zonedCalls.single.arguments['payload'], 'test');

    // 插件把 TZDateTime 序列化为 ISO8601 字符串 + 时区名
    final String iso =
        zonedCalls.single.arguments['scheduledDateTimeISO8601'] as String;
    expect(zonedCalls.single.arguments['timeZoneName'], isNotEmpty);
    final int deltaMs =
        DateTime.parse(iso).millisecondsSinceEpoch - before.millisecondsSinceEpoch;
    expect(deltaMs, inInclusiveRange(2000, 5000));
  });

  test('只读自检不触发系统授权请求', () async {
    final NotificationService svc = NotificationService();
    final AlarmCapability cap = await svc.checkCapability();

    expect(cap.initialized, isTrue);
    expect(cap.notificationsAllowed, isTrue);
    expect(cap.exactAlarmsAllowed, isTrue);
    // 关键：自检只读，不能弹授权对话框
    expect(
      allCalls.any((MethodCall c) =>
          c.method == 'requestNotificationsPermission' ||
          c.method == 'requestExactAlarmsPermission'),
      isFalse,
    );
  });
}
