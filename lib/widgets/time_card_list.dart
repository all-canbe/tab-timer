import 'package:flutter/material.dart';

import '../models/time_card.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// 卡片序列编辑列表：序号圆点 + 名称 + 时长 + 删除，支持拖拽排序。
///
/// 与原版 `TimeCardList.vue` 的差异（有意升级）：原版手写了约 100 行的
/// HTML5 drag + 350ms 长按兜底，Flutter 版直接用内置 `ReorderableListView`，
/// 手机/桌面手感一致，代码量近零。
class TimeCardList extends StatelessWidget {
  const TimeCardList({
    super.key,
    required this.cards,
    required this.onRemove,
    required this.onReorder,
  });

  final List<TimeCard> cards;
  final void Function(int index) onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: BoxDecoration(
          color: SetBeatColors.surface,
          borderRadius: BorderRadius.circular(SetBeatRadii.md),
          border: Border.all(color: SetBeatColors.line),
        ),
        child: const Text(
          '点击上方"添加时长卡片"开始创建',
          textAlign: TextAlign.center,
          style: TextStyle(color: SetBeatColors.text3, fontSize: 13),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: SetBeatColors.surface,
        borderRadius: BorderRadius.circular(SetBeatRadii.md),
        border: Border.all(color: SetBeatColors.line),
      ),
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: true,
        // onReorderItem：newIndex 已按「移除旧位」校准，无需再减一
        onReorderItem: onReorder,
        proxyDecorator: (Widget child, int index, Animation<double> anim) =>
            AnimatedBuilder(
          animation: anim,
          builder: (_, _) => Material(
            color: SetBeatColors.surfaceHi,
            borderRadius: BorderRadius.circular(10),
            elevation: 0,
            child: child,
          ),
        ),
        itemCount: cards.length,
        itemBuilder: (BuildContext context, int index) {
          final TimeCard card = cards[index];
          final Color base = parseHexColor(card.color);
          return ListTile(
            key: ValueKey<String>(card.id),
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.drag_indicator,
                        size: 18, color: SetBeatColors.text3),
                  ),
                ),
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration:
                      BoxDecoration(color: base, shape: BoxShape.circle),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            title: Text(
              card.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: SetBeatColors.text1,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: SetBeatColors.accentSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    formatTime(card.duration),
                    style: TextStyle(
                      color: base,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures()
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close,
                      size: 18, color: SetBeatColors.text3),
                  onPressed: () => onRemove(index),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
