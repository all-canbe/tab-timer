import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/timer_state.dart';

/// 运行中状态的持久化。对应原版 `RunningStateStorage`。
///
/// 原版的缺陷：只在暂停时写入，全工程没有任何地方读取，
/// 即设计文档里的 `resumeFromBackground()` 从未实现。
/// Flutter 版保留同样的写入语义，但补齐读取链路（见 TimerController.restore）。
class RunningStateRepository {
  static const String storageKey = 'andro-timer-running-state';

  Future<void> save(RunningState state) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(state.toJson()));
  }

  Future<RunningState?> get() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return RunningState.fromJson(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }
}
