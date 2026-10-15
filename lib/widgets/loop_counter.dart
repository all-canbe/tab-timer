import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 循环次数调节器：1–99，与原版 `LoopCounter.vue` 同构。
class LoopCounter extends StatelessWidget {
  const LoopCounter({super.key, required this.count, required this.onChanged});

  final int count;
  final ValueChanged<int> onChanged;

  void _step(int delta) =>
      onChanged((count + delta).clamp(1, 99));

  @override
  Widget build(BuildContext context) => Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: SetBeatColors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: SetBeatColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _Btn(
              icon: Icons.remove,
              enabled: count > 1,
              onTap: () => _step(-1),
            ),
            SizedBox(
              width: 56,
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: SetBeatColors.text1,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            ),
            _Btn(
              icon: Icons.add,
              enabled: count < 99,
              onTap: () => _step(1),
            ),
          ],
        ),
      );
}

class _Btn extends StatelessWidget {
  const _Btn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 40,
            height: 36,
            child: Icon(
              icon,
              size: 20,
              color: enabled ? SetBeatColors.text2 : SetBeatColors.text3,
            ),
          ),
        ),
      );
}
