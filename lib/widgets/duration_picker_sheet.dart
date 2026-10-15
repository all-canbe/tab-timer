import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/time_card.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// 时长选择底部弹层。
///
/// 与原版 `DurationPickerSheet.vue` 的差异（有意升级）：原版是「时/分/秒」三组
/// 加减按钮，Flutter 版换成真正的三列滚轮——点按次数更少、手感更原生，
/// 且数值范围与原版完全一致（时 0–9、分 0–59、秒按 5 步进）。
///
/// 实现注意（真机踩过的坑）：**不能在 build 期读
/// `FixedExtentScrollController.selectedItem`** —— 控制器尚未 attach 时它的
/// 实现是 `_positions.single`，会抛 `Bad state: No element`，整个弹层 build
/// 崩掉只剩灰色遮罩。因此选中值一律用普通 int 状态持有，控制器只负责滚动。
Future<TimeCard?> showDurationPickerSheet(BuildContext context) {
  return showModalBottomSheet<TimeCard>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SetBeatColors.surface,
    builder: (_) => const _DurationPickerSheet(),
  );
}

class _PresetChip {
  const _PresetChip(this.label, this.h, this.m, this.s);
  final String label;
  final int h;
  final int m;
  final int s;
}

const List<_PresetChip> _presetChips = <_PresetChip>[
  _PresetChip('15s', 0, 0, 15),
  _PresetChip('30s', 0, 0, 30),
  _PresetChip('45s', 0, 0, 45),
  _PresetChip('1min', 0, 1, 0),
  _PresetChip('5min', 0, 5, 0),
  _PresetChip('25min', 0, 25, 0),
  _PresetChip('45min', 0, 45, 0),
  _PresetChip('1h', 1, 0, 0),
];

/// 秒轮盘的可选值：0,5,10,...,55（与原版 5 秒步进一致）
const List<int> _secondValues = <int>[
  0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, //
];

class _DurationPickerSheet extends StatefulWidget {
  const _DurationPickerSheet();

  @override
  State<_DurationPickerSheet> createState() => _DurationPickerSheetState();
}

class _DurationPickerSheetState extends State<_DurationPickerSheet> {
  final TextEditingController _name = TextEditingController();

  // 选中值用普通 int 持有（下标），控制器只在 hasClients 时驱动。
  // 初始 00:01:00 与原版一致。
  int _hourIndex = 0;
  int _minuteIndex = 1;
  int _secondIndex = 0;

  late final FixedExtentScrollController _hour =
      FixedExtentScrollController(initialItem: _hourIndex);
  late final FixedExtentScrollController _minute =
      FixedExtentScrollController(initialItem: _minuteIndex);
  late final FixedExtentScrollController _second =
      FixedExtentScrollController(initialItem: _secondIndex);

  int get _totalSeconds =>
      _hourIndex * 3600 + _minuteIndex * 60 + _secondValues[_secondIndex];

  bool get _valid => _name.text.trim().isNotEmpty && _totalSeconds > 0;

  @override
  void dispose() {
    _name.dispose();
    _hour.dispose();
    _minute.dispose();
    _second.dispose();
    super.dispose();
  }

  void _onHourChanged(int i) => setState(() => _hourIndex = i);
  void _onMinuteChanged(int i) => setState(() => _minuteIndex = i);
  void _onSecondChanged(int i) => setState(() => _secondIndex = i);

  void _applyChip(_PresetChip p) {
    setState(() {
      _hourIndex = p.h;
      _minuteIndex = p.m;
      final int i = _secondValues.indexOf(p.s);
      _secondIndex = i < 0 ? 0 : i;
    });
    // jumpToItem 只在控制器已挂载后调用
    if (_hour.hasClients) _hour.jumpToItem(_hourIndex);
    if (_minute.hasClients) _minute.jumpToItem(_minuteIndex);
    if (_second.hasClients) _second.jumpToItem(_secondIndex);
  }

  void _confirm() {
    if (!_valid) return;
    const List<String> palette = SetBeatColors.presetColorHexes;
    final String color = palette[math.Random().nextInt(palette.length)];
    Navigator.of(context).pop(TimeCard(
      id: generateId(),
      label: _name.text.trim(),
      duration: _totalSeconds,
      color: color,
    ));
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Center(
                  child: Text(
                    '添加时长卡片',
                    style: TextStyle(
                      color: SetBeatColors.text1,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  maxLength: 10,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                      color: SetBeatColors.text1, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: '名称（如：训练 / 休息）',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final _PresetChip p in _presetChips)
                      ActionChip(
                        label: Text(p.label),
                        backgroundColor: SetBeatColors.surface2,
                        side: const BorderSide(color: SetBeatColors.line),
                        labelStyle: const TextStyle(
                            color: SetBeatColors.text2, fontSize: 13),
                        onPressed: () => _applyChip(p),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _wheel('时', _hour, _hourIndex,
                        List<int>.generate(10, (int i) => i), _onHourChanged),
                    const _WheelSeparator(),
                    _wheel('分', _minute, _minuteIndex,
                        List<int>.generate(60, (int i) => i), _onMinuteChanged),
                    const _WheelSeparator(),
                    _wheel('秒', _second, _secondIndex, _secondValues,
                        _onSecondChanged),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text.rich(
                    TextSpan(
                      text: '总时长 ',
                      style: const TextStyle(
                          color: SetBeatColors.text2, fontSize: 13),
                      children: <InlineSpan>[
                        TextSpan(
                          text: formatTime(_totalSeconds),
                          style: const TextStyle(
                            color: SetBeatColors.accent,
                            fontWeight: FontWeight.w700,
                            fontFeatures: <FontFeature>[
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _SheetButton(
                        label: '取消',
                        filled: false,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SheetButton(
                        label: '确认',
                        filled: true,
                        enabled: _valid,
                        onTap: _confirm,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _wheel(
    String label,
    FixedExtentScrollController controller,
    int selectedIndex,
    List<int> values,
    ValueChanged<int> onChanged,
  ) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: SetBeatColors.text2,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 84,
          height: 132,
          decoration: BoxDecoration(
            color: SetBeatColors.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SetBeatColors.line),
          ),
          child: CupertinoPicker(
            scrollController: controller,
            itemExtent: 40,
            magnification: 1.1,
            squeeze: 1.15,
            useMagnifier: true,
            selectionOverlay: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: SetBeatColors.accent.withValues(alpha: 0.5),
                ),
              ),
            ),
            onSelectedItemChanged: onChanged,
            children: <Widget>[
              for (final int v in values)
                Center(
                  child: Text(
                    v.toString().padLeft(2, '0'),
                    style: TextStyle(
                      // 选中行主题橙、未选中行灰，滚动时更接近系统滚轮观感
                      color: values[selectedIndex] == v
                          ? SetBeatColors.accent
                          : SetBeatColors.text3,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures()
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WheelSeparator extends StatelessWidget {
  const _WheelSeparator();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Text(
          ':',
          style: TextStyle(
            color: SetBeatColors.text3,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.filled,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool filled;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool active = filled ? enabled : true;
    return Opacity(
      opacity: active ? 1 : 0.35,
      child: Material(
        color: filled ? Colors.transparent : SetBeatColors.surface2,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: active ? onTap : null,
          child: Ink(
            height: 48,
            decoration: filled
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        SetBeatColors.accent,
                        SetBeatColors.accent2
                      ],
                    ),
                    boxShadow: enabled
                        ? const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x59FF6B35),
                              blurRadius: 14,
                              offset: Offset(0, 4),
                            ),
                          ]
                        : null,
                  )
                : null,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: filled ? Colors.white : SetBeatColors.text2,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
