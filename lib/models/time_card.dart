/// 时间卡片：训练序列的最小单元。
///
/// 字段与 JSON 键名与原版 `src/types/index.ts` 的 `TimeCard` 完全一致，
/// 便于将来任何形式的数据迁移与逐字段对照。
///
/// 本文件保持为纯数据模型：所有格式化逻辑集中在 `utils/format.dart`，
/// 由那里的扩展方法提供 `durationLabel` 等展示能力，避免循环依赖。
class TimeCard {
  /// 唯一标识
  final String id;

  /// 显示名称（如「训练」「休息」「专注」）
  final String label;

  /// 时长，单位：秒
  final int duration;

  /// 十六进制色值，如 `#ff6b35`
  final String color;

  const TimeCard({
    required this.id,
    required this.label,
    required this.duration,
    required this.color,
  });

  factory TimeCard.fromJson(Map<String, dynamic> json) => TimeCard(
        id: json['id'] as String,
        label: json['label'] as String,
        duration: (json['duration'] as num).toInt(),
        color: json['color'] as String,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'label': label,
        'duration': duration,
        'color': color,
      };

  TimeCard copyWith({
    String? id,
    String? label,
    int? duration,
    String? color,
  }) =>
      TimeCard(
        id: id ?? this.id,
        label: label ?? this.label,
        duration: duration ?? this.duration,
        color: color ?? this.color,
      );

  @override
  String toString() => 'TimeCard($label, ${duration}s, $color)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeCard &&
          other.id == id &&
          other.label == label &&
          other.duration == duration &&
          other.color == color;

  @override
  int get hashCode => Object.hash(id, label, duration, color);
}
