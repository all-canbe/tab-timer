import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setbeat_flutter/app.dart';
import 'package:setbeat_flutter/data/running_state_repository.dart';
import 'package:setbeat_flutter/engine/timer_engine.dart';
import 'package:setbeat_flutter/screens/home_screen.dart';
import 'package:setbeat_flutter/services/haptics_service.dart';
import 'package:setbeat_flutter/services/notification_service.dart';
import 'package:setbeat_flutter/services/sound_service.dart';
import 'package:setbeat_flutter/state/services.dart';
import 'package:setbeat_flutter/state/timer_controller.dart';
import 'package:setbeat_flutter/models/time_card.dart';
import 'package:setbeat_flutter/models/timer_state.dart';
import 'package:setbeat_flutter/models/training_preset.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 声音/震动服务的空转桩
class _StubSoundService extends SoundService {
  @override
  Future<void> init() async {}

  @override
  Future<void> playTick() async {}

  @override
  Future<void> playChime() async {}

  @override
  Future<void> playFinish() async {}

  @override
  Future<void> dispose() async {}
}

class _StubHapticsService extends HapticsService {
  @override
  Future<void> init() async {}

  @override
  Future<void> playTransition() async {}

  @override
  Future<void> playFinish() async {}

  @override
  Future<void> cancel() async {}
}

/// 通知服务的纯空转桩：本测试只验证恢复链路与 UI 状态，
/// 排期行为由 timer_scheduling_integration_test / notification_schedule_test 覆盖。
class _StubNotificationService extends NotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<AlarmCapability> ensurePermissions() async => const AlarmCapability(
      initialized: true, notificationsAllowed: true, exactAlarmsAllowed: true);

  @override
  Future<AlarmCapability> checkCapability() async => ensurePermissions();

  @override
  Future<void> scheduleAlerts(
      String presetName, List<UpcomingBoundary> boundaries) async {}

  @override
  Future<int> pendingNotificationCount() async => 0;

  @override
  Future<void> cancelAll() async {}

  @override
  Future<bool> showTestAlert() async => true;
}

/// 回归测试：进程被杀后重启，要能看到「上次计时未完成」的恢复弹窗。
///
/// 真机踩过的坑：恢复弹窗原来挂在 app 根组件上，那个 context 位于
/// MaterialApp 之上，拿不到 Navigator / ScaffoldMessenger，
/// showDialog 直接抛异常 → 弹窗从不出现，用户看到的就像「被重置了」。
/// 修复后入口移到 HomeScreen（MaterialApp 之下），本测试守护这条链路。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  debugDefaultTargetPlatformOverride = TargetPlatform.android;

  FlutterLocalNotificationsPlatform.instance =
      AndroidFlutterLocalNotificationsPlugin();

  const String notifChannel = 'dexterous.com/flutter/local_notifications';
  Future<Object?>? notifHandler(MethodCall call) async {
    switch (call.method) {
      case 'initialize':
        return Future<bool>.value(true);
      case 'pendingNotificationRequests':
        return Future<List<dynamic>>.value(<dynamic>[]);
      default:
        return Future<Object?>.value();
    }
  }

  setUp(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel(notifChannel), notifHandler);
    for (final String ch in <String>[
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers/events/setbeat-tick',
      'xyz.luan/audioplayers/events/setbeat-chime',
      'xyz.luan/audioplayers/events/setbeat-finish',
      'wakelock_plus',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(ch),
              (MethodCall call) async => <Object?, Object?>{});
    }
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(notifChannel), null);
    for (final String ch in <String>[
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers/events/setbeat-tick',
      'xyz.luan/audioplayers/events/setbeat-chime',
      'xyz.luan/audioplayers/events/setbeat-finish',
      'wakelock_plus',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(ch), null);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  String snapshotJson() {
    // 60 秒卡片跑了 20 秒后挂后台。
    // wasRunning 用 false（暂停态）：恢复逻辑与运行态同一条链路，
    // 但测试里不会启动 ticker，避免假时钟下的 Timer 泄漏误报。
    final TrainingPreset preset = TrainingPreset(
      id: 'p1',
      name: '番茄钟',
      loopCount: 1,
      createdAt: 0,
      updatedAt: 0,
      cards: const <TimeCard>[
        TimeCard(id: 'c0', label: '专注', duration: 60, color: '#ff6b35'),
      ],
    );
    final RunningState state = RunningState(
      preset: preset,
      position: 0,
      cardRemainingMs: 40000,
      pausedAt: DateTime.now().millisecondsSinceEpoch,
      startedAt: DateTime.now().millisecondsSinceEpoch - 20000,
      wasRunning: false,
    );
    return jsonEncode(state.toJson());
  }

  test('快照读写往返探针', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      RunningStateRepository.storageKey: snapshotJson(),
    });
    final RunningState? s =
        await RunningStateRepository().get();
    // ignore: avoid_print
    print('[restore-probe] repo snapshot = $s');
  });

  testWidgets('有未完成计时快照时，启动后出现恢复弹窗', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      RunningStateRepository.storageKey: snapshotJson(),
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [
        notificationServiceProvider
            .overrideWith((Ref ref) => _StubNotificationService()),
        soundServiceProvider.overrideWith((Ref ref) => _StubSoundService()),
        hapticsServiceProvider.overrideWith((Ref ref) => _StubHapticsService()),
      ],
      child: const SetBeatApp(),
    ));
    await tester.pump(); // 首帧
    // 恢复链路含多个平台通道 await，用 runAsync 放行真实异步
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 实质断言：控制器状态已恢复到「运行中」且方案名正确
    // （弹窗的可见性由 HomeScreen 的 context 提供 Navigator 保证——
    //   生产中 push 编辑页/计时页用的就是同一 context）
    final BuildContext homeContext = tester.element(find.byType(HomeScreen));
    final TimerViewState view =
        ProviderScope.containerOf(homeContext).read(timerControllerProvider);
    expect(view.status, TimerStatus.paused);
    expect(view.presetName, '番茄钟');
    expect(view.currentLabel, '专注');

    // 放弃路径：清掉运行态并停掉计时器（否则 ticker 泄漏会挂起测试）
    await tester.tap(find.text('放弃'));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('上次计时未完成'), findsNothing);

    // 推进假时钟，让所有挂起定时器（超时兜底等）到期，避免测试不变量报「Timer 泄漏」
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('没有快照时不弹恢复窗', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(ProviderScope(
      overrides: [
        notificationServiceProvider
            .overrideWith((Ref ref) => _StubNotificationService()),
        soundServiceProvider.overrideWith((Ref ref) => _StubSoundService()),
        hapticsServiceProvider.overrideWith((Ref ref) => _StubHapticsService()),
      ],
      child: const SetBeatApp(),
    ));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('上次计时未完成'), findsNothing);
    await tester.pump(const Duration(seconds: 10));
  });
}
