import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 环形进度：底环 + 按剩余时间收缩的进度弧（圆头 + 同色发光）。
/// 对应原版 `TimerPage.vue` 的 SVG `stroke-dashoffset` 实现。
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.size,
    required this.progress,
    required this.color,
    required this.child,
  });

  final double size;
  final double progress;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: _RingPainter(progress: progress, color: color),
              ),
            ),
            child,
          ],
        ),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // 原版：viewBox 300，描边 10，半径 140
    final double stroke = size.width * (10 / 300);
    final double radius = size.width / 2 - stroke / 2;
    final Offset center = size.center(Offset.zero);
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    // 底环
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = const Color(0x0FFFFFFF),
    );

    if (progress <= 0) return;

    // 发光层
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // 主弧
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
