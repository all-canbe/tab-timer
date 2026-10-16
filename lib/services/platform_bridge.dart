import 'package:flutter/services.dart';

/// 平台能力桥：只放极小的原生能力调用。
///
/// 本地时区名这类「一行原生代码」的事，不值得为此引入一个第三方插件——
/// `flutter_timezone` 就是反例：它还在用 AGP 7 时代的老 DSL（`compileSdkVersion`），
/// 在 AGP 9 下会让整个构建挂掉（provider 无值）。
class PlatformBridge {
  PlatformBridge._();

  static const MethodChannel _channel = MethodChannel('setbeat/platform');

  /// 本地 IANA 时区名（如 `Asia/Shanghai`），供提醒排期使用。
  /// 拿不到时回退 `UTC`——提醒时间可能偏移，但绝不阻塞主流程。
  static Future<String> getTimeZone() async {
    try {
      final String? name =
          await _channel.invokeMethod<String>('getTimeZone');
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {
      // 平台未实现 / 非 Android 目标
    }
    return 'UTC';
  }

  /// 打开本应用的通知设置页。横幅 / 锁屏 / 铃声这几个开关决定「弹不弹」，
  /// 直接跳过去比让用户自己翻层级快得多。
  static Future<bool> openNotificationSettings() =>
      _open('openNotificationSettings');

  /// 打开「闹钟和提醒」权限页（精确闹钟）
  static Future<bool> openExactAlarmSettings() =>
      _open('openExactAlarmSettings');

  /// 打开应用详情页（电池策略 / 自启动白名单）
  static Future<bool> openAppDetailsSettings() => _open('openAppDetailsSettings');

  /// 本应用是否已豁免电池优化。
  /// 返回 null 表示平台未实现（非 Android 目标），调用方不应据此报警。
  static Future<bool?> isIgnoringBatteryOptimizations() async {
    try {
      return await _channel
          .invokeMethod<bool>('isIgnoringBatteryOptimizations');
    } catch (_) {
      return null;
    }
  }

  /// 申请豁免电池优化（弹系统对话框）。已豁免则直接返回 true。
  static Future<bool> requestIgnoreBatteryOptimizations() =>
      _open('requestIgnoreBatteryOptimizations');

  /// 厂商标识：`Build.MANUFACTURER` 的小写形式，如 `oppo` / `xiaomi` / `vivo`。
  static Future<String> getManufacturer() =>
      _str('getManufacturer');

  /// 品牌标识：`Build.BRAND` 的小写形式。realme / iqoo 这类子品牌只体现在
  /// BRAND 上，所以两个都得拿。
  static Future<String> getBrand() => _str('getBrand');

  /// 打开厂商的「自启动管理」页。没有标准 API，原生侧按厂商逐个试组件名；
  /// 全部失败会兜底到应用详情页。返回 false 表示连兜底都没起来。
  static Future<bool> openAutoStartSettings() => _open('openAutoStartSettings');

  /// 打开「耗电管理 / 省电策略」页（ColorOS 的「允许完全后台行为」在这里）。
  static Future<bool> openPowerManagerSettings() =>
      _open('openPowerManagerSettings');

  // ---------------------------------------------------------------- 提醒排期

  /// 用 [alertsJson] **整体替换**当前全部提醒排期。
  ///
  /// 为什么不复用 `flutter_local_notifications`：那个插件的通知 id 同时就是
  /// AlarmManager 的 requestCode，导致「多个提醒共用一个通知槽位」与
  /// 「每个提醒都触发」互斥。详见原生侧 `SetBeatAlerts` 的类注释。
  static Future<bool> scheduleTimerAlerts(String alertsJson) async {
    try {
      return await _channel.invokeMethod<bool>(
            'scheduleTimerAlerts',
            <String, Object?>{'alerts': alertsJson},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// 取消全部提醒排期。原生侧逐个探测系统里真实存在的闹钟，
  /// 不依赖任何本地记录，所以不存在「记录失准导致漏取消」的问题。
  static Future<void> cancelTimerAlerts() async {
    try {
      await _channel.invokeMethod<void>('cancelTimerAlerts');
    } catch (_) {}
  }

  /// 系统里**真实存在**的闹钟数量。
  ///
  /// 与「读本地记录」的关键差别：应用被 force-stop 后系统会清空闹钟，
  /// 这个值会如实变成 0 —— 用它判断排期成没成不会有假阳性。
  static Future<int> armedAlertCount() async {
    try {
      return await _channel.invokeMethod<int>('armedAlertCount') ?? -1;
    } catch (_) {
      return -1;
    }
  }

  /// 3 秒后的提醒测试，走与真实提醒完全相同的路径。
  static Future<bool> showTestAlert() =>
      _open('showTestAlert');

  /// 升级期一次性清理：收掉旧版本用插件排下的残留闹钟。
  static Future<void> cancelLegacyAlerts() async {
    try {
      await _channel.invokeMethod<void>('cancelLegacyAlerts');
    } catch (_) {}
  }

  static Future<String> _str(String method) async {
    try {
      return await _channel.invokeMethod<String>(method) ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<bool> _open(String method) async {
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } catch (_) {
      return false;
    }
  }
}
