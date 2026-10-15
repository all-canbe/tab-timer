import 'time_card.dart';

/// 训练方案（预设）。
///
/// JSON 键名与原版 `src/types/index.ts` 的 `TrainingPreset` 一致。
/// `createdAt` / `updatedAt` 为毫秒时间戳（与 JS `Date.now()` 同单位）。
class TrainingPreset {
  final String id;
  final String name;
  final List<TimeCard> cards;

  /// 循环组数，≥ 1
  final int loopCount;

  final int createdAt;
  final int updatedAt;

  const TrainingPreset({
    required this.id,
    required this.name,
    required this.cards,
    required this.loopCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TrainingPreset.fromJson(Map<String, dynamic> json) => TrainingPreset(
        id: json['id'] as String,
        name: json['name'] as String,
        cards: (json['cards'] as List<dynamic>)
            .map((dynamic e) => TimeCard.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        loopCount: (json['loopCount'] as num).toInt(),
        createdAt: (json['createdAt'] as num).toInt(),
        updatedAt: (json['updatedAt'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'cards': cards.map((TimeCard c) => c.toJson()).toList(growable: false),
        'loopCount': loopCount,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  TrainingPreset copyWith({
    String? id,
    String? name,
    List<TimeCard>? cards,
    int? loopCount,
    int? createdAt,
    int? updatedAt,
  }) =>
      TrainingPreset(
        id: id ?? this.id,
        name: name ?? this.name,
        cards: cards ?? this.cards,
        loopCount: loopCount ?? this.loopCount,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// 展开序列 = cards 平铺 loopCount 次。
  ///
  /// 与原版 `TimerEngine.expandCards` 语义一致：只在开始/重置时生成一次，
  /// 运行期仅移动索引，避免重建大对象。
  List<TimeCard> expand() {
    final List<TimeCard> result = <TimeCard>[];
    for (int i = 0; i < loopCount; i++) {
      result.addAll(cards);
    }
    return result;
  }

  @override
  String toString() => 'TrainingPreset($name, ${cards.length} cards, x$loopCount)';
}
