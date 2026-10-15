import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/time_card.dart';
import '../models/training_preset.dart';
import '../state/preset_controller.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/duration_picker_sheet.dart';
import '../widgets/loop_counter.dart';
import '../widgets/time_card_list.dart';

/// 方案编辑页。与原版 `EditorPage.vue` 同构。
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, this.preset});

  final TrainingPreset? preset;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  late final TextEditingController _nameController;
  late final List<TimeCard> _cards;
  late int _loopCount;
  bool _saved = false;

  bool get _isEditing => widget.preset != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.preset?.name ?? '');
    _cards = List<TimeCard>.from(widget.preset?.cards ?? <TimeCard>[]);
    _loopCount = widget.preset?.loopCount ?? 6;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty && _cards.isNotEmpty;

  Future<void> _addCard() async {
    final TimeCard? card = await showDurationPickerSheet(context);
    if (card == null) return;
    setState(() => _cards.add(card));
  }

  void _removeAt(int index) => setState(() => _cards.removeAt(index));

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final TimeCard moved = _cards.removeAt(oldIndex);
      _cards.insert(newIndex, moved);
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final bool ok = await ref.read(presetControllerProvider.notifier).save(
          name: _nameController.text,
          cards: _cards,
          loopCount: _loopCount,
          original: widget.preset,
        );
    if (!ok || !mounted) return;
    // 与原版一致：先给「已保存」反馈，450ms 后再返回
    setState(() => _saved = true);
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final String summary = _cards.isEmpty
        ? ''
        : '${_cards.length} 张卡片 · 循环 $_loopCount 次 · 共 '
            '${calcTotalDurationStr(_cards, _loopCount)}';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    _isEditing ? '编辑方案' : '新建方案',
                    style: const TextStyle(
                      color: SetBeatColors.text2,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _HeaderBar(
                    nameController: _nameController,
                    canSave: _canSave,
                    onBack: () => Navigator.of(context).pop(),
                    onSave: _save,
                    onNameChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _AddCardButton(onTap: _addCard),
                          const SizedBox(height: 16),
                          TimeCardList(
                            cards: _cards,
                            onRemove: _removeAt,
                            onReorder: _reorder,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (summary.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    _Summary(text: summary),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      LoopCounter(
                        count: _loopCount,
                        onChanged: (int v) => setState(() => _loopCount = v),
                      ),
                      // 原版此处为 disabled 的占位按钮，保留同样的视觉语义
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: SetBeatColors.surface,
                          borderRadius:
                              BorderRadius.circular(SetBeatRadii.sm),
                          border: Border.all(color: SetBeatColors.line),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.low_priority,
                                size: 16, color: SetBeatColors.text3),
                            const SizedBox(width: 6),
                            Text(
                              '排序',
                              style: TextStyle(
                                color: SetBeatColors.text3,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 保存成功反馈：与原版一致的右上角 teal 徽章
          Positioned(
            top: 16 + MediaQuery.of(context).padding.top,
            right: 16,
            child: AnimatedOpacity(
              opacity: _saved ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: const SavedTip(),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.nameController,
    required this.canSave,
    required this.onBack,
    required this.onSave,
    required this.onNameChanged,
  });

  final TextEditingController nameController;
  final bool canSave;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onNameChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          _IconButton(icon: Icons.chevron_left, onTap: onBack),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: nameController,
              maxLength: 20,
              onChanged: (_) => onNameChanged(),
              style: const TextStyle(
                color: SetBeatColors.text1,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                hintText: '方案名称',
                counterText: '',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: canSave ? onSave : null,
              child: Ink(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: canSave
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            SetBeatColors.accent,
                            SetBeatColors.accent2
                          ],
                        )
                      : null,
                  color: canSave ? null : SetBeatColors.surface,
                  boxShadow: canSave
                      ? const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x59FF6B35),
                            blurRadius: 14,
                            offset: Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    '保存',
                    style: TextStyle(
                      color: canSave
                          ? Colors.white
                          : SetBeatColors.text3.withValues(alpha: 0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: SetBeatColors.surface,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 22, color: SetBeatColors.text2),
          ),
        ),
      );
}

class _AddCardButton extends StatelessWidget {
  const _AddCardButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: SetBeatColors.accentSoft,
        borderRadius: BorderRadius.circular(SetBeatRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(SetBeatRadii.md),
          onTap: onTap,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SetBeatRadii.md),
              border: Border.all(
                color: SetBeatColors.accent.withValues(alpha: 0.55),
                width: 1.5,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.add, color: SetBeatColors.accent, size: 20),
                SizedBox(width: 8),
                Text(
                  '添加时长卡片',
                  style: TextStyle(
                    color: SetBeatColors.accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: SetBeatColors.accentSoft,
          borderRadius: BorderRadius.circular(SetBeatRadii.sm),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: SetBeatColors.accent2,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      );
}

/// 「已保存」浮动提示
class SavedTip extends StatelessWidget {
  const SavedTip({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: SetBeatColors.teal,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x664ECDC4), blurRadius: 18, offset: Offset(0, 6)),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.check, size: 16, color: Color(0xFF062826)),
            SizedBox(width: 6),
            Text(
              '已保存',
              style: TextStyle(
                color: Color(0xFF062826),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}
