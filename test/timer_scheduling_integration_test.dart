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

/// 端到端（控制器 → 通知服务 → 平台通道）验证真实计时到底排了哪些提醒。
///
/// 真机反馈「测试提醒能弹、真实计时到点不弹」，这里先把 Dart 侧发出的排期
/// 参数原样抓出来看清楚，避免继续在系统侧空猜。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  debugDefaultTargetPlatformOverride = TargetPlatform.android;

  FlutterLocalNotificationsPlatform.instance =
      AndroidFlutterLocalNotificationsPlugin();

  const String channel = 'dexterous.com/flutter/local_notifications';
  final List<MethodCall> zonedCalls = <MethodCall>[];
  final List<MethodCall> allCalls = <MethodCall>[];

  Future<Object?>? handler(MethodCall call) {
    allCalls.add(call);
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
      case 'pendingNotificationRequests':
        return Future<List<dynamic>>.value(
          List<dynamic>.generate(
              zonedCalls.length, (int i) => <String, Object?>{'id': i}),
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
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(channel), handler);

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
        .setMockMethodCallHandler(const MethodChannel(channel), null);
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

  List<String> scheduledTitles() => zonedCalls
      .map((MethodCall c) => c.arguments['title'] as String)
      .toList();

  /// 相对「现在」的剩余秒数，容差 ±2s（now 取自 start 完成之后）
  List<int> scheduledDelaysSec() {
    final DateTime now = DateTime.now();
    return zonedCalls.map((MethodCall c) {
      final String iso = c.arguments['scheduledDateTimeISO8601'] as String;
      return DateTime.parse(iso).difference(now).inSeconds;
    }).toList();
  }

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
    expect(delays[0], inInclusiveRange(88, 90));   // 段1（第 2 轮）开始
    expect(delays[1], inInclusiveRange(178, 180)); // 训练结束
    expect(scheduledTitles(), <String>['段1 · 第 2/2 轮', '训练完成']);
  });

  test('全部段位都短于 1 分钟时，仅保留结束提醒', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(timerControllerProvider.notifier).start(preset(<int>[15, 30], 2));

    expect(scheduledTitles(), <String>['训练完成']);
  });

  test('真实计时：开始后不会残留已排期被误取消', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(timerControllerProvider.notifier)
        .start(preset(<int>[60], 1));
    // 60s 卡的边界就是结束点，始终保留
    expect(zonedCalls, hasLength(1));

    // start 之后不应再出现取消动作
    final int cancelsBefore = allCalls
        .where((MethodCall c) => c.method == 'cancelAllPendingNotifications')
        .length;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final int cancelsAfter = allCalls
        .where((MethodCall c) => c.method == 'cancelAllPendingNotifications')
        .length;
    expect(cancelsAfter, cancelsBefore);
  });
}
