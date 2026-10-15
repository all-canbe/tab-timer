import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/preset_repository.dart';
import '../data/running_state_repository.dart';
import '../data/settings_repository.dart';
import '../models/app_settings.dart';
import '../services/haptics_service.dart';
import '../services/notification_service.dart';
import '../services/sound_service.dart';

/// 各服务与仓库的单例入口。全部在应用启动时初始化一次。
final Provider<PresetRepository> presetRepositoryProvider =
    Provider<PresetRepository>((Ref ref) => PresetRepository());

final Provider<RunningStateRepository> runningStateRepositoryProvider =
    Provider<RunningStateRepository>((Ref ref) => RunningStateRepository());

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>((Ref ref) => SettingsRepository());

final Provider<SoundService> soundServiceProvider =
    Provider<SoundService>((Ref ref) {
  final SoundService service = SoundService();
  ref.onDispose(service.dispose);
  return service;
});

final Provider<HapticsService> hapticsServiceProvider =
    Provider<HapticsService>((Ref ref) => HapticsService());

final Provider<NotificationService> notificationServiceProvider =
    Provider<NotificationService>((Ref ref) => NotificationService());

/// 启动引导结果：每个服务的成败都有记录，UI 据此给出可见提示。
class BootstrapReport {
  final Map<String, String> failures = <String, String>{};

  void fail(String service, Object error) =>
      failures[service] = error.toString();

  bool get ok => failures.isEmpty;

  /// 给用户看的一句话提示
  String? get hint =>
      ok ? null : '部分能力初始化失败：${failures.keys.join('、')}';
}

/// 启动引导：合成音效、探测震动能力、初始化提醒通道、加载设置。
///
/// 重要设计约束（由一次真机卡启动屏事故得来）：
/// **服务初始化绝不能阻塞首帧，且单个服务失败不能拖垮其他服务。**
/// 因此每个服务独立 try/catch + 超时兜底，结果写入 [BootstrapReport]，
/// 由 UI 决定要不要提示用户。
final FutureProvider<BootstrapReport> appBootstrapProvider =
    FutureProvider<BootstrapReport>((Ref ref) async {
  final BootstrapReport report = BootstrapReport();

  Future<void> safe(String name, Future<void> Function() task) async {
    try {
      // 平台通道调用挂死的兜底：最多等 5 秒
      await task().timeout(const Duration(seconds: 5));
    } on TimeoutException {
      report.fail(name, '初始化超时（5 秒）');
    } catch (e) {
      report.fail(name, e);
    }
  }

  await safe('声音', () => ref.read(soundServiceProvider).init());
  await safe('震动', () => ref.read(hapticsServiceProvider).init());
  await safe('提醒', () => ref.read(notificationServiceProvider).init());
  await safe('设置', () async {
    // 把持久化的开关即时反映到服务上
    final AppSettings settings =
        await ref.read(settingsControllerProvider.future);
    ref.read(soundServiceProvider).enabled = settings.soundEnabled;
    ref.read(hapticsServiceProvider).enabled = settings.vibrationEnabled;
  });

  return report;
});

/// 用户设置。异步加载，UI 直接 watch。
class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => ref.read(settingsRepositoryProvider).get();

  Future<void> setSoundEnabled(bool value) =>
      _write((AppSettings s) => s.copyWith(soundEnabled: value));

  Future<void> setVibrationEnabled(bool value) =>
      _write((AppSettings s) => s.copyWith(vibrationEnabled: value));

  Future<void> setNotificationEnabled(bool value) =>
      _write((AppSettings s) => s.copyWith(notificationEnabled: value));

  Future<void> _write(AppSettings Function(AppSettings) transform) async {
    final AppSettings next =
        transform(state.value ?? AppSettings.defaults);
    state = AsyncData<AppSettings>(next);
    await ref.read(settingsRepositoryProvider).set(next);
    ref.read(soundServiceProvider).enabled = next.soundEnabled;
    ref.read(hapticsServiceProvider).enabled = next.vibrationEnabled;
  }
}

final AsyncNotifierProvider<SettingsController, AppSettings>
    settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
        SettingsController.new);
