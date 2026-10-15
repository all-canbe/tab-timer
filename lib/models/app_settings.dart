/// 用户设置。JSON 键名与原版 `src/types/index.ts` 的 `AppSettings` 一致。
class AppSettings {
  final bool soundEnabled;
  final bool vibrationEnabled;

  /// 新增（原版没有）：系统通知开关。
  /// 原版因为通知在实机不生效而彻底放弃了通知提醒，Flutter 版把它做成可选项。
  final bool notificationEnabled;

  const AppSettings({
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.notificationEnabled = true,
  });

  static const AppSettings defaults = AppSettings();

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        // 逐字段给默认值：单个字段缺失或类型不对时不会把整份设置读崩
        soundEnabled: json['soundEnabled'] as bool? ?? true,
        vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
        notificationEnabled: json['notificationEnabled'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'soundEnabled': soundEnabled,
        'vibrationEnabled': vibrationEnabled,
        'notificationEnabled': notificationEnabled,
      };

  AppSettings copyWith({
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? notificationEnabled,
  }) =>
      AppSettings(
        soundEnabled: soundEnabled ?? this.soundEnabled,
        vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
        notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      );
}
