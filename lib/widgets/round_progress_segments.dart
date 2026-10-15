import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 轮次进度段：已完成=青色渐变、当前=橙色渐变、未开始=暗色。
/// 对应原版 `RoundProgress.vue`。
class RoundProgressSegments extends StatelessWidget {
  const RoundProgressSegments({
    super.key,
    required this.currentRound,
    required this.totalRounds,
  });

  final int currentRound;
  final int totalRounds;

  @override
  Widget build(BuildContext context) {
    if (totalRounds <= 0) return const SizedBox.shrink();

    return Row(
      children: <Widget>[
        for (int i = 1; i <= totalRounds; i++) ...<Widget>[
          if (i > 1) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: i < currentRound
                    ? const LinearGradient(
                        colors: <Color>[
                          SetBeatColors.teal,
                          Color(0xFF7EE8E0)
                        ],
                      )
                    : i == currentRound
                        ? const LinearGradient(
                            colors: <Color>[
                              SetBeatColors.accent,
                              SetBeatColors.accent2
                            ],
                          )
                        : null,
                color: i > currentRound
                    ? const Color(0x14FFFFFF)
                    : null,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
