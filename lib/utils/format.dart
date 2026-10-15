import 'dart:math' as math;

import '../models/time_card.dart';

/// 时长格式化与通用工具。与 `src/utils/format.ts` 逐函数对齐。
///
/// 唯一有意偏离原版的地方：进位修正。
/// 原版 `Math.round((total % 3600) / 60)` 在 total = 7199 秒时会算出
/// `Math.round(59.98) = 60`，显示成 `1h60min` —— 这是原版的显示缺陷，
/// 此处做进位处理，输出 `2h`。已在改造记录中登记为修正项。

String _p2(int v) => v.toString().padLeft(2, '0');

/// `45` → `00:45`；`3661` → `1:01:01`。
/// 小时段不补零，分秒段补零，与原版一致。
String formatTime(int seconds) {
  if (seconds < 0) seconds = 0;
  final int h = seconds ~/ 3600;
  final int m = (seconds % 3600) ~/ 60;
  final int s = seconds % 60;
  if (h > 0) return '$h:${_p2(m)}:${_p2(s)}';
  return '${_p2(m)}:${_p2(s)}';
}

/// 毫秒 → 向上取整到秒再格式化。与包住 `Math.ceil(ms / 1000)` 一致。
String formatMs(double ms) => formatTime((ms / 1000).ceil());

/// 短格式：`45s` / `25min` / `1h` / `1h30min`（含进位修正）。
String formatDurationShort(int seconds) {
  if (seconds >= 3600) {
    int h = seconds ~/ 3600;
    int m = ((seconds % 3600) / 60).round();
    if (m >= 60) {
      h += 1;
      m = 0;
    }
    return m > 0 ? '${h}h${m}min' : '${h}h';
  }
  if (seconds >= 60) {
    return '${seconds ~/ 60}min';
  }
  return '${seconds}s';
}

final math.Random _rand = math.Random();

/// 与原版 `generateId` 同构：36 进制时间戳 + 6 位 36 进制随机串。
String generateId() {
  final String ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final String rnd = _rand
      .nextInt(0x7FFFFFFF)
      .toRadixString(36)
      .padLeft(6, '0')
      .substring(0, 6);
  return '$ts$rnd';
}

/// 方案总时长（秒）= 卡片时长之和 × 循环次数。
int calcTotalDuration(Iterable<TimeCard> cards, int loopCount) {
  int sum = 0;
  for (final TimeCard c in cards) {
    sum += c.duration;
  }
  return sum * loopCount;
}

/// 方案总时长的短格式。
String calcTotalDurationStr(Iterable<TimeCard> cards, int loopCount) =>
    formatDurationShort(calcTotalDuration(cards, loopCount));

/// 卡片时长序列，用于方案卡片的摘要行，如 `25min+5min`。
String durationSequence(Iterable<TimeCard> cards) =>
    cards.map((TimeCard c) => formatDurationShort(c.duration)).join('+');

/// 展示层便捷扩展：`card.durationLabel`
extension TimeCardFormatting on TimeCard {
  String get durationLabel => formatDurationShort(duration);
}
