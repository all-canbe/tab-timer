import 'package:flutter/material.dart';

import '../models/time_card.dart';
import '../models/training_preset.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// 「我的方案」卡片：左侧配色竖条 + 名称 + 时长序列/循环信息 + 播放按钮。
/// 与原版 `PresetCard.vue` 同构。
class PresetCard extends StatelessWidget {
  const PresetCard({
    super.key,
    required this.preset,
    required this.onStart,
    required this.onEdit,
  });

  final TrainingPreset preset;
  final VoidCallback onStart;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final Color base = parseHexColor(
      preset.cards.isEmpty ? '#ff6b35' : preset.cards.first.color,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(SetBeatRadii.md),
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SetBeatColors.surface,
            borderRadius: BorderRadius.circular(SetBeatRadii.md),
            border: Border.all(color: SetBeatColors.line),
          ),
          child: Row(
            children: <Widget>[
              _ColorDots(cards: preset.cards),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      preset.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SetBeatColors.text1,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      durationSequence(preset.cards),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: base,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures()
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '循环 ${preset.loopCount} 次 · 共 '
                      '${calcTotalDurationStr(preset.cards, preset.loopCount)}',
                      style: const TextStyle(
                        color: SetBeatColors.text3,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _PlayButton(color: base, onTap: onStart),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorDots extends StatelessWidget {
  const _ColorDots({required this.cards});

  final List<TimeCard> cards;

  @override
  Widget build(BuildContext context) {
    final List<TimeCard> shown = cards.take(4).toList();
    return SizedBox(
      width: 26,
      child: Column(
        children: <Widget>[
          for (int i = 0; i < shown.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 5),
            Container(
              width: 22,
              height: 5,
              decoration: BoxDecoration(
                color: parseHexColor(shown[i].color),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
          if (cards.length > 4)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${cards.length - 4}',
                style: const TextStyle(
                    color: SetBeatColors.text3, fontSize: 9, height: 1),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[color, Color.lerp(color, Colors.white, 0.35)!],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 26),
          ),
        ),
      );
}
