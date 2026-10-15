import 'package:flutter/material.dart';

import '../models/timer_state.dart';
import '../theme/app_theme.dart';

/// 运行页控制按钮组：跳过 | 暂停/继续（主操作，橙色高亮） | 重置。
class TimerControls extends StatelessWidget {
  const TimerControls({
    super.key,
    required this.status,
    required this.onPause,
    required this.onResume,
    required this.onSkip,
    required this.onReset,
  });

  final TimerStatus status;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onSkip;
  final VoidCallback onReset;

  bool get _paused => status == TimerStatus.paused;

  @override
  Widget build(BuildContext context) {
    final bool finished = status == TimerStatus.finished;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _SecondaryButton(
          icon: Icons.skip_next_rounded,
          label: '跳过',
          onTap: finished ? null : onSkip,
        ),
        const SizedBox(width: 18),
        _PrimaryButton(
          icon: _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          label: _paused ? '继续' : '暂停',
          onTap: finished ? null : (_paused ? onResume : onPause),
        ),
        const SizedBox(width: 18),
        _SecondaryButton(
          icon: Icons.refresh_rounded,
          label: '重置',
          onTap: finished ? null : onReset,
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Opacity(
          opacity: disabled ? 0.4 : 1,
          child: Ink(
            width: 88,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[SetBeatColors.accent, SetBeatColors.accent2],
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x59FF6B35),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Opacity(
          opacity: disabled ? 0.4 : 1,
          child: Ink(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0x0FFFFFFF),
              border: Border.all(color: SetBeatColors.lineStrong),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, color: SetBeatColors.text1, size: 22),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    color: SetBeatColors.text2,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
