import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setbeat_flutter/models/time_card.dart';
import 'package:setbeat_flutter/models/training_preset.dart';
import 'package:setbeat_flutter/state/timer_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 端到端（控制器 → 通知服务 → 原生通道）验证真实计时到底排了哪些提醒。
///
/// 原设计意图不变：真机反馈「测试提醒能弹、真实计时到点不弹」时，先把
/// Dart 侧发出的排期载荷原样抓出来看清楚，避免在系统侧空猜。
/// 只是排期已经从 flutter_local_notifications 迁移到原生 `SetBeatAlerts`，
/// 抓取点随之换成 `setbeat/platform`。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  debugDefaultTargetPlatformOverride = TargetPlatform.android;

  // 权限探测仍走插件，平台实例是 late 字段，必须手工注入
  FlutterLocalNotificationsPlatform.instance =
      AndroidFlutterLocalNotificationsPlugin();

  const String flnChannel = 'dexterous.com/flutter/local_notifications';
  const String nativeChannel = 'setbeat/platform';

  final List<MethodCall> nativeCalls = <MethodCall>[];
  final List<MethodCall> flnCalls = <MethodCall>[];
  int armedCount = 0;

  List<MethodCall> scheduleCalls() => nativeCalls
      .where((MethodCall c) => c.method == 'scheduleTimerAlerts')
      .toList();

  /// 最近一次下发的提醒列表
  List<Map<String, dynamic>> lastAlerts() {
    final MethodCall call = scheduleCalls().last;
    final Map<Object?, Object?> args = call.arguments as Map<Object?, Object?>;
    return (jsonDecode(args['alerts']! as String) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  List<String> scheduledTitles() =>
      lastAlerts().map((Map<String, dynamic> a) => a['title'] as String).toList();

  /// 相对「现在」的触发延迟秒数。容差 ±2s（now 取自 start 完成之后）。
  List<int> scheduledDelaysSec() {
    final int now = DateTime.now().millisecondsSinceEpoch;
    return lastAlerts()
        .map((Map<String, dynamic> a) => ((a['atMs'] as int) - now) / 1000)
        .map((double d) => d.round())
        .toList();
  }

  Future<Object?>? flnHandler(MethodCall call) {
    flnCalls.add(call);
    switch (call.method) {
      case 'initialize':
        return Future<bool>.value(true);
      case 'createNotificationChannel':
      case 'cancelAllPendingNotifications':
      case 'cancel':
        return Future<void>.value();
      case 'requestNotificationsPermission':
      case 'requestExactAlarmsPermission':
        return Future<bool>.value(true);
      case 'areNotificationsEnabled':
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
        return Future<bool>.value(true);
      case 'armedAlertCount':
        return Future<int>.value(armedCount);
      case 'getTimeZone':
        return Future<String>.value('Asia/Shanghai');
      case 'showTestAlert':
        return Future<bool>.value(true);
      default:
        return Future<void>.value();
    }
  }

  setUp(() {
    nativeCalls.clear();
    flnCalls.clear();
    armedCount = 0;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(flnChannel), flnHandler);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(nativeChannel), nativeHandler);

    // 测试环境没有 audioplayers 平台实现，mock 掉避免异步初始化错误污染用例
    for (final String ch in <String>[
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers/setbeat-tick',
      'xyz.luan/audioplayers/setbeat-chime',
      'xyz.luan/audioplayers/setbeat-finish',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              MethodChannel(ch), (MethodCall call) async => <Object?, Object?>{});
    }
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(flnChannel), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(nativeChannel), null);
    for (final String ch in <String>[
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers/setbeat-tick',
      'xyz.luan/audioplayers/setbeat-chime',
      'xyz.luan/audioplayers/setbeat-finish',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(ch), null);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  TrainingPreset preset(List<int> seconds, int loops) => TrainingPreset(
        id: 'p1',
        name: '测试方案',
        loopCount: loops,
        createdAt: 0,
        updatedAt: 0,
        cards: <TimeCard>[
          for (int i = 0; i < seconds.length; i++)
            TimeCard(
              id: 'c$i',
              label: '段${i + 1}',
              duration: seconds[i],
              color: '#ff6b35',
            ),
        ],
      );

  test('真实计时：边界按 ≥1 分钟规则过滤，结束点始终保留', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    // 2 张卡（60s / 30s）× 2 循环 = 180s
    // 原始边界：60s(段2=30s✗) 90s(段1=60s✓) 150s(段2=30s✗) 180s(结束✓)
    await container
        .read(timerControllerProvider.notifier)
        .start(preset(<int>[60, 30], 2));

    final List<int> delays = scheduledDelaysSec();
    expect(delays.length, 2);
    expect(delays[0], inInclusiveRange(88, 90)); // 段1（第 2 轮）开始
    expect(delays[1], inInclusiveRange(178, 180)); // 训练结束
    expect(scheduledTitles(), <String>['段1 · 第 2/2 轮', '训练完成']);
  });

  test('全部段位都短于 1 分钟时，仅保留结束提醒', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(timerControllerProvider.notifier)
        .start(preset(<int>[15, 30], 2));

    expect(scheduledTitles(), <String>['训练完成']);
  });

  test('结束提醒带 isFinal 标记 —— 原生侧据此收掉常驻通知', () async {
    // 不带这个标记的话，计时结束时常驻通知与结束提醒会同时显示「训练完成」，
    // 文案一模一样，用户的第一反应就是「怎么发了两条」。
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(timerControllerProvider.notifier)
        .start(preset(<int>[60], 1));

    final List<Map<String, dynamic>> alerts = lastAlerts();
    expect(alerts.single['isFinal'], isTrue);
  });

  test('每个提醒的 seq 唯一 —— 撞了会在 AlarmManager 里互相覆盖', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(timerControllerProvider.notifier)
        .start(preset(<int>[60, 45], 2));

    final List<Object?> seqs =
        lastAlerts().map((Map<String, dynamic> a) => a['seq']).toList();
    expect(seqs.toSet().length, seqs.length);
  });

  test('真实计时：开始后不会残留已排期被误取消', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(timerControllerProvider.notifier)
        .start(preset(<int>[60], 1));
    // 60s 卡的边界就是结束点，始终保留
    expect(scheduleCalls(), hasLength(1));

    // start 之后不应再出现取消除原有排期的动作。这里只检查原生通道：
    // init() 里有一次升级清理（cancelLegacyAlerts）与插件侧的缓存清理，
    // 它们只在初始化时发生，不属于「计时期间的误取消」。
    final int cancelsBefore =
        nativeCalls.where((MethodCall c) => c.method == 'cancelTimerAlerts').length;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final int cancelsAfter =
        nativeCalls.where((MethodCall c) => c.method == 'cancelTimerAlerts').length;
    expect(cancelsAfter, cancelsBefore);
  });
}
