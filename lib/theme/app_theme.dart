import 'package:flutter/material.dart';

/// 设计令牌 —— 与原版 `src/style.css` 的 `:root` 逐项对应。
///
/// 色值一个都不改：这是「1:1 复刻」的底线，也是两版并排对比的前提。
/// CSS 的 `rgba(a, x)` 换算成 Flutter 的 `0x__RRGGBB`，alpha 按 `x * 255` 四舍五入。
class SetBeatColors {
  SetBeatColors._();

  static const Color bg0 = Color(0xFF07080F);
  static const Color bg1 = Color(0xFF0D1020);
  static const Color surface = Color(0xFF141830);
  static const Color surface2 = Color(0xFF1B2038);
  static const Color surfaceHi = Color(0xFF232A4A);

  /// rgba(255,255,255,.07)
  static const Color line = Color(0x12FFFFFF);

  /// rgba(255,255,255,.14)
  static const Color lineStrong = Color(0x24FFFFFF);

  static const Color text1 = Color(0xFFF4F6FB);
  static const Color text2 = Color(0xFF9AA3BF);
  static const Color text3 = Color(0xFF5C6480);

  static const Color accent = Color(0xFFFF6B35);
  static const Color accent2 = Color(0xFFFF8C5A);

  /// rgba(255,107,53,.12)
  static const Color accentSoft = Color(0x1FFF6B35);

  static const Color teal = Color(0xFF4ECDC4);

  /// 卡片可用的 6 个预设色，与原版 `DurationPickerSheet.PRESET_COLORS` 一致
  static const List<String> presetColorHexes = <String>[
    '#ff6b35',
    '#4ecdc4',
    '#ffd166',
    '#a78bfa',
    '#f472b6',
    '#34d399',
  ];
}

/// 圆角令牌：lg 20 / md 14 / sm 10
class SetBeatRadii {
  SetBeatRadii._();

  static const double lg = 20;
  static const double md = 14;
  static const double sm = 10;
}

/// 把 `#rrggbb` 解析成不透明颜色；解析失败回退主题色，不让 UI 崩掉。
Color parseHexColor(String hex, {Color fallback = SetBeatColors.accent}) {
  String h = hex.trim().replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  final int? value = int.tryParse(h, radix: 16);
  if (value == null) return fallback;
  return Color(value & 0xFFFFFFFF);
}

/// 全局深色主题。
///
/// 仅深色是原版的设计决定（运动场景最优），不是偷懒。
ThemeData buildSetBeatTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: SetBeatColors.accent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: SetBeatColors.accent,
    secondary: SetBeatColors.teal,
    surface: SetBeatColors.bg1,
    surfaceContainerHighest: SetBeatColors.surfaceHi,
    onPrimary: const Color(0xFFFFFFFF),
    onSurface: SetBeatColors.text1,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: SetBeatColors.bg1,
    splashFactory: InkSparkle.splashFactory,
    // 原版全局 -webkit-tap-highlight-color: transparent + 无水波纹涟漪偏好
    splashColor: const Color(0x00000000),
    highlightColor: const Color(0x00000000),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
          color: SetBeatColors.text1,
          fontWeight: FontWeight.w700,
          letterSpacing: 2),
      titleLarge: TextStyle(color: SetBeatColors.text1),
      bodyMedium: TextStyle(color: SetBeatColors.text1),
      bodySmall: TextStyle(color: SetBeatColors.text2),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SetBeatColors.surface,
      hintStyle: const TextStyle(color: SetBeatColors.text3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SetBeatRadii.sm + 3),
        borderSide: const BorderSide(color: SetBeatColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SetBeatRadii.sm + 3),
        borderSide: const BorderSide(color: SetBeatColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SetBeatRadii.sm + 3),
        borderSide: const BorderSide(color: SetBeatColors.accent),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: SetBeatColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SetBeatRadii.lg),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: SetBeatColors.surface,
      modalBackgroundColor: SetBeatColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
    ),
  );
}
