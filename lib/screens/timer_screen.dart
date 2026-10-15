import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/timer_controller.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/progress_ring.dart';
import '../widgets/round_progress_segments.dart';
import '../widgets/timer_controls.dart';

/// 计时运行页：全屏深色 + 环形进度 + 大数字 + 控制按钮。
/// 与原版 `TimerPage.vue` 同构。
class TimerScreen extends ConsumerStatefulWidget {
  const TimerScreen({super.key});

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen> {
  @override
  Widget build(BuildContext context) {
    final TimerViewState view = ref.watch(timerControllerProvider);
    final TimerController controller = ref.read(timerControllerProvider.notifier);
    final Color phase = parseHexColor(view.currentColor);
    final String digits = formatTime(
      view.isFinished ? 0 : controller.secondsLeft.value,
    );
    final bool long = digits.length > 5;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: <Widget>[
          // 顶部阶段色氛围光
          Positioned(
            top: -180,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 420,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.4,
                    colors: <Color>[
                      phase.withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                    stops: const <double>[0, 0.65],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (view.alarmHint != null) _AlarmHint(text: view.alarmHint!),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _BackButton(
                      onTap: () async {
                        await controller.exit();
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: view.presetName,
                          style: const TextStyle(
                            color: SetBeatColors.text1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const TextSpan(
                          text: '  ·  ',
                          style: TextStyle(color: SetBeatColors.text3),
                        ),
                        TextSpan(
                          text:
                              '${view.currentRound} / ${view.totalRounds} 轮',
                          style:
                              const TextStyle(color: SetBeatColors.text2),
                        ),
                      ],
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 22),
                  ValueListenableBuilder<double>(
                    valueListenable: controller.ringProgress,
                    builder: (_, double progress, _) => ProgressRing(
                      size: 300,
                      progress: progress,
                      color: phase,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          _PhaseBadge(
                              label: view.currentLabel, color: phase),
                          const SizedBox(height: 10),
                          ValueListenableBuilder<int>(
                            valueListenable: controller.secondsLeft,
                            builder: (_, int secs, _) => Text(
                              formatTime(view.isFinished ? 0 : secs),
                              style: TextStyle(
                                color: SetBeatColors.text1,
                                fontSize: long ? 40 : 56,
                                fontWeight: FontWeight.w700,
                                letterSpacing: long ? 1 : 2,
                                height: 1,
                                fontFeatures: const <FontFeature>[
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  TimerControls(
                    status: view.status,
                    onPause: () => controller.pause(),
                    onResume: () => controller.resume(),
                    onSkip: () => controller.skip(),
                    onReset: () => controller.reset(),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: 300,
                    child: RoundProgressSegments(
                      currentRound: view.currentRound,
                      totalRounds: view.totalRounds,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (view.alarmHint == null &&
                      (view.isRunning || view.isPaused))
                    Text(
                      view.scheduledAlerts > 0
                          ? '系统提醒已排期 ${view.scheduledAlerts} 条 · 息屏/后台到点弹出'
                          : '短于 1 分钟的段位不提醒，仅训练结束时提醒',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: SetBeatColors.text3,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseBadge extends StatelessWidget {
  const _PhaseBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(color: color, blurRadius: 10),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      );
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0x0FFFFFFF),
        shape: const CircleBorder(
            side: BorderSide(color: SetBeatColors.lineStrong)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 38,
            height: 38,
            child: Icon(Icons.chevron_left,
                size: 20, color: SetBeatColors.text1),
          ),
        ),
      );
}

class _AlarmHint extends StatelessWidget {
  const _AlarmHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x33FFD166),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.notification_important_rounded,
                size: 16, color: SetBeatColors.text1),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                    color: SetBeatColors.text1, fontSize: 12),
              ),
            ),
          ],
        ),
      );
}
