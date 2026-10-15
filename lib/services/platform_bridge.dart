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

  static Future<bool> _open(String method) async {
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } catch (_) {
      return false;
    }
  }
}
