import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/timer_state.dart';
import '../models/time_card.dart';
import '../models/training_preset.dart';
import '../state/preset_controller.dart';
import '../state/services.dart';
import '../state/timer_controller.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/alarm_diagnostics_sheet.dart';
import '../widgets/brand_mark.dart';
import '../widgets/preset_card.dart';
import 'editor_screen.dart';
import 'timer_screen.dart';

/// 首页：快速开始 + 我的方案。与原版 `HomePage.vue` 同构。
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final PresetState state = ref.read(presetControllerProvider);
      if (!state.loaded) ref.read(presetControllerProvider.notifier).load();
      // 恢复入口必须放在 MaterialApp 之下的组件里：
      // app 根组件的 context 拿不到 Navigator / ScaffoldMessenger，
      // 在那里 showDialog 会抛异常，恢复弹窗就永远不出现（真机踩过）。
      _maybeRestore();
    });
  }

  /// 启动时检查有没有没跑完的计时（原版从未实现的链路）。
  Future<void> _maybeRestore() async {
    final RestoreOutcome outcome =
        await ref.read(timerControllerProvider.notifier).tryRestore();
    if (!mounted) {
      // ignore: avoid_print
      print('[restore-probe] not mounted');
      return;
    }

    if (outcome == RestoreOutcome.alreadyFinished) {
      // 离开期间自然跑完了：明确告知，而不是静默清空让用户以为被重置
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('上一次训练已在后台结束'),
        duration: Duration(seconds: 3),
      ));
      return;
    }
    if (outcome != RestoreOutcome.restored) return;

    final TimerViewState view = ref.read(timerControllerProvider);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('上次计时未完成'),
        content: Text('「${view.presetName}」还在进行中，要继续吗？'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(timerControllerProvider.notifier).exit();
            },
            child: const Text('放弃'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const TimerScreen(),
              ));
            },
            style: FilledButton.styleFrom(
              backgroundColor: SetBeatColors.accent,
            ),
            child: const Text('继续计时'),
          ),
        ],
      ),
    );
  }

  void _startPreset(TrainingPreset preset) {
    // 原版在首次交互时解锁 Web Audio；Flutter 无此限制，直接开跑
    ref.read(timerControllerProvider.notifier).start(preset);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TimerScreen()),
    );
  }

  Future<void> _openEditor([TrainingPreset? preset]) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => EditorScreen(preset: preset),
    ));
    // 编辑完回来刷新列表
    ref.read(presetControllerProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final PresetState state = ref.watch(presetControllerProvider);
    final BootstrapReport? bootstrap = ref.watch(appBootstrapProvider).value;
    final int totalMinutes = state.presets.fold<int>(
      0,
      (int acc, TrainingPreset p) =>
          acc + calcTotalDuration(p.cards, p.loopCount) ~/ 60,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Header(
                presetCount: state.presets.length,
                totalMinutes: totalMinutes,
                onNew: () => _openEditor(),
              ),
              if (bootstrap != null && !bootstrap.ok) ...<Widget>[
                const SizedBox(height: 12),
                _BootstrapBanner(hint: bootstrap.hint!),
              ],
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const _SectionTitle('快速开始'),
                      _QuickGrid(onStart: _startPreset),
                      const SizedBox(height: 24),
                      _MineSection(
                        state: state,
                        onStart: _startPreset,
                        onEdit: _openEditor,
                        onNew: () => _openEditor(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.presetCount,
    required this.totalMinutes,
    required this.onNew,
  });

  final int presetCount;
  final int totalMinutes;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            SetBeatColors.accent,
                            SetBeatColors.accent2
                          ],
                        ),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x59FF6B35),
                            blurRadius: 14,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(child: BrandMark(size: 22)),
                    ),
                    const SizedBox(width: 10),
                    const Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: 'Set',
                            style: TextStyle(color: SetBeatColors.accent),
                          ),
                          TextSpan(
                            text: 'Beat',
                            style: TextStyle(color: SetBeatColors.text1),
                          ),
                        ],
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                if (presetCount > 0) ...<Widget>[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 46),
                    child: Text(
                      '$presetCount 个方案 · 累计 $totalMinutes 分钟',
                      style: const TextStyle(
                          color: SetBeatColors.text3, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: SetBeatColors.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => showAlarmDiagnosticsSheet(context),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(Icons.notifications_active_outlined,
                    size: 18, color: SetBeatColors.text2),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onNew,
              child: Ink(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[SetBeatColors.accent, SetBeatColors.accent2],
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x59FF6B35),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.add, color: Colors.white, size: 18),
                    SizedBox(width: 4),
                    Text(
                      '新建',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
}

/// 服务初始化失败提示条：让用户看得见「哪个能力没就绪」，而不是无声无息
class _BootstrapBanner extends StatelessWidget {
  const _BootstrapBanner({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x26FFD166),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.warning_amber_rounded,
                size: 16, color: SetBeatColors.text1),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hint,
                style: const TextStyle(
                    color: SetBeatColors.text1, fontSize: 12),
              ),
            ),
          ],
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text(
              text,
              style: const TextStyle(
                color: SetBeatColors.text2,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const Spacer(),
            if (trailing != null)
              Text(
                trailing!,
                style: const TextStyle(
                    color: SetBeatColors.text3, fontSize: 11),
              ),
          ],
        ),
      );
}

class _QuickGrid extends StatelessWidget {
  const _QuickGrid({required this.onStart});

  final void Function(TrainingPreset) onStart;

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.55,
        children: <Widget>[
          for (final TrainingPreset t in quickTemplates)
            _QuickCard(preset: t, onStart: () => onStart(t)),
        ],
      );
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({required this.preset, required this.onStart});

  final TrainingPreset preset;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final Color base = parseHexColor(preset.cards.first.color);
    final String detail = preset.cards
        .map((TimeCard c) => '${(c.duration / 60).round()}min')
        .join(' + ');
    final String total =
        '${calcTotalDuration(preset.cards, preset.loopCount) ~/ 60} 分钟';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(SetBeatRadii.md),
        onTap: onStart,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: SetBeatColors.surface,
            borderRadius: BorderRadius.circular(SetBeatRadii.md),
            border: Border.all(color: SetBeatColors.line),
          ),
          child: Stack(
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: base,
                          shape: BoxShape.circle,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                                color: base.withValues(alpha: 0.6),
                                blurRadius: 8),
                          ],
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          preset.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: SetBeatColors.text1,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preset.loopCount > 1
                        ? '$detail · ×${preset.loopCount}'
                        : detail,
                    style: const TextStyle(
                      color: SetBeatColors.text2,
                      fontSize: 12,
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    total,
                    style: const TextStyle(
                      color: SetBeatColors.text3,
                      fontSize: 11,
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        base,
                        Color.lerp(base, Colors.white, 0.35)!,
                      ],
                    ),
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MineSection extends StatelessWidget {
  const _MineSection({
    required this.state,
    required this.onStart,
    required this.onEdit,
    required this.onNew,
  });

  final PresetState state;
  final void Function(TrainingPreset) onStart;
  final void Function(TrainingPreset?) onEdit;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SectionTitle(
            '我的方案',
            trailing: state.presets.isEmpty ? null : '${state.presets.length} 个',
          ),
          if (state.presets.isEmpty)
            _EmptyState(onNew: onNew)
          else
            Column(
              children: <Widget>[
                for (int i = 0; i < state.presets.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: 12),
                  PresetCard(
                    preset: state.presets[i],
                    onStart: () => onStart(state.presets[i]),
                    onEdit: () => onEdit(state.presets[i]),
                  ),
                ],
              ],
            ),
        ],
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onNew});

  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: <Widget>[
            Icon(Icons.radio_button_unchecked,
                size: 56, color: SetBeatColors.text3),
            const SizedBox(height: 10),
            const Text(
              '还没有自定义方案',
              style: TextStyle(
                color: SetBeatColors.text2,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '点击右上角「新建」，用小时/分钟自由编排你的节奏',
              textAlign: TextAlign.center,
              style: TextStyle(color: SetBeatColors.text3, fontSize: 12),
            ),
          ],
        ),
      );
}
