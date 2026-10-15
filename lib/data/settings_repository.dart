import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// 用户设置持久化。对应原版 `SettingsStorage`。
///
/// 语义与原版一致：读取时把默认值作为兜底逐字段合并，
/// 因此单个字段缺失或类型异常都不会导致设置整体失效。
class SettingsRepository {
  static const String storageKey = 'andro-timer-settings';

  Future<AppSettings> get() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return AppSettings.defaults;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return AppSettings.fromJson(decoded);
      return AppSettings.defaults;
    } catch (_) {
      return AppSettings.defaults;
    }
  }

  Future<void> set(AppSettings settings) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(settings.toJson()));
  }

  /// 局部更新，等价于原版 `SettingsStorage.set(Partial<AppSettings>)`。
  Future<AppSettings> update({
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? notificationEnabled,
  }) async {
    final AppSettings current = await get();
    final AppSettings merged = current.copyWith(
      soundEnabled: soundEnabled,
      vibrationEnabled: vibrationEnabled,
      notificationEnabled: notificationEnabled,
    );
    await set(merged);
    return merged;
  }
}
