import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/training_preset.dart';

/// 训练方案持久化。对应原版 `PresetStorage`（@capacitor/preferences）。
///
/// 存储结构刻意保持与原版一致：单一 key 下存 `Record<id, TrainingPreset>`，
/// 读出时按 `updatedAt` 降序，新增/修改方案不会打乱其它条目。
/// 键名沿用 `andro-timer-presets`。
class PresetRepository {
  static const String storageKey = 'andro-timer-presets';

  Future<Map<String, dynamic>> _readMap(SharedPreferences prefs) async {
    final String? raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } on FormatException {
      // 数据损坏时返回空集合而不是让整个首页崩掉
      return <String, dynamic>{};
    }
  }

  Future<List<TrainingPreset>> getAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> map = await _readMap(prefs);
    final List<TrainingPreset> list = <TrainingPreset>[];
    for (final Object? value in map.values) {
      if (value is Map<String, dynamic>) {
        try {
          list.add(TrainingPreset.fromJson(value));
        } catch (_) {
          // 跳过结构不合法的单条记录，不影响其余方案
        }
      }
    }
    list.sort((TrainingPreset a, TrainingPreset b) =>
        b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<TrainingPreset?> getById(String id) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> map = await _readMap(prefs);
    final Object? value = map[id];
    if (value is Map<String, dynamic>) {
      try {
        return TrainingPreset.fromJson(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> save(TrainingPreset preset) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> map = await _readMap(prefs);
    map[preset.id] = preset.toJson();
    await prefs.setString(storageKey, jsonEncode(map));
  }

  Future<void> delete(String id) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> map = await _readMap(prefs);
    if (map.remove(id) != null) {
      await prefs.setString(storageKey, jsonEncode(map));
    }
  }
}
