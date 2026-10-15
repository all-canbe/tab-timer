import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/time_card.dart';
import '../models/training_preset.dart';
import '../utils/format.dart';
import 'services.dart';

/// 首页「我的方案」的状态。
class PresetState {
  final List<TrainingPreset> presets;
  final bool loaded;

  const PresetState({this.presets = const <TrainingPreset>[], this.loaded = false});

  bool get isEmpty => presets.isEmpty;
}

/// 方案的增删改查。对应原版 `stores/presets.ts`。
class PresetController extends Notifier<PresetState> {
  @override
  PresetState build() => const PresetState();

  /// 首次进入首页时拉取。幂等。
  Future<void> load() async {
    final List<TrainingPreset> list =
        await ref.read(presetRepositoryProvider).getAll();
    state = PresetState(presets: list, loaded: true);
  }

  /// 新建或更新。返回是否成功（名称为空或没有卡片时失败）。
  Future<bool> save({
    required String name,
    required List<TimeCard> cards,
    required int loopCount,
    TrainingPreset? original,
  }) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty || cards.isEmpty) return false;

    final int now = DateTime.now().millisecondsSinceEpoch;
    final TrainingPreset preset = TrainingPreset(
      id: original?.id ?? generateId(),
      name: trimmed,
      cards: List<TimeCard>.unmodifiable(cards),
      loopCount: loopCount < 1 ? 1 : loopCount,
      createdAt: original?.createdAt ?? now,
      updatedAt: now,
    );
    await ref.read(presetRepositoryProvider).save(preset);
    await load();
    return true;
  }

  Future<void> remove(String id) async {
    await ref.read(presetRepositoryProvider).delete(id);
    await load();
  }
}

final NotifierProvider<PresetController, PresetState> presetControllerProvider =
    NotifierProvider<PresetController, PresetState>(PresetController.new);

/// 「快速开始」模板：点击即用临时方案开始计时，不写入方案列表。
///
/// 与原版 `HomePage.quickTemplates` 完全一致。
final List<TrainingPreset> quickTemplates = _buildTemplates();

List<TrainingPreset> _buildTemplates() {
  TimeCard card(String label, int duration, String color) => TimeCard(
        id: 'quick-$label-$duration',
        label: label,
        duration: duration,
        color: color,
      );

  return <TrainingPreset>[
    TrainingPreset(
      id: 'quick-pomodoro',
      name: '番茄钟',
      loopCount: 4,
      createdAt: 0,
      updatedAt: 0,
      cards: <TimeCard>[
        card('专注', 25 * 60, '#ff6b35'),
        card('休息', 5 * 60, '#4ecdc4'),
      ],
    ),
    TrainingPreset(
      id: 'quick-focus45',
      name: '专注课',
      loopCount: 2,
      createdAt: 0,
      updatedAt: 0,
      cards: <TimeCard>[
        card('专注', 45 * 60, '#a78bfa'),
        card('休息', 15 * 60, '#4ecdc4'),
      ],
    ),
    TrainingPreset(
      id: 'quick-deep',
      name: '深度工作',
      loopCount: 3,
      createdAt: 0,
      updatedAt: 0,
      cards: <TimeCard>[
        card('专注', 50 * 60, '#f472b6'),
        card('休息', 10 * 60, '#ffd166'),
      ],
    ),
    TrainingPreset(
      id: 'quick-hour',
      name: '整点专注',
      loopCount: 1,
      createdAt: 0,
      updatedAt: 0,
      cards: <TimeCard>[
        card('专注', 60 * 60, '#34d399'),
      ],
    ),
  ];
}
