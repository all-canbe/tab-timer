import 'dart:math' as math;

import 'package:flutter/material.dart';

/// SetBeat 品牌标记：环形进度（右上缺口）+ 时钟指针 + 缺口处的节拍点。
///
/// 与原版 `HomePage.vue` 的 logo SVG、Android 启动图矢量同源。
/// 用 CustomPainter 而不是贴图：任意尺寸无损、可任意着色（橙色渐变底配白线，
/// 或深色底配橙线），也不往包里塞多余资源。
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 20,
    this.strokeColor = const Color(0xFFFFFFFF),
    this.dotColor,
  });

  final double size;
  final Color strokeColor;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _BrandMarkPainter(
          strokeColor: strokeColor,
          dotColor: dotColor ?? strokeColor,
        ),
      );
}

class _BrandMarkPainter extends CustomPainter {
  _BrandMarkPainter({required this.strokeColor, required this.dotColor});

  final Color strokeColor;
  final Color dotColor;

  // 几何以「环半径 = 1」为单位，与 tool/gen_brand_icons.py 完全一致
  static const double _ringSw = 0.28;
  static const double _handSw = 0.269;
  static const double _gapHalf = 30.0; // 度
  static const double _gapCenterDeg = -47.7; // 度，屏幕坐标顺时针
  static const Offset _handTop = Offset(0, -0.4615);
  static const Offset _handElbowEnd = Offset(0.3077, 0.1923);
  static const Offset _dotCenter = Offset(0.7881, -0.8654);
  static const double _dotR = 0.1923;
  static const double _extent = 1.362;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.shortestSide * 0.5 / _extent * 1.02;
    final double deg = math.pi / 180.0;

    // 环：从缺口一侧顺时针扫过 300°，圆头
    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * _ringSw
      ..strokeCap = StrokeCap.round
      ..color = strokeColor;
    final Rect rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(rect, (_gapCenterDeg + _gapHalf) * deg, 300 * deg, false,
        ringPaint);

    // 时钟指针：12 点方向 -> 圆心 -> 右下，肘点在圆心
    final Paint handPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * _handSw
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = strokeColor;
    final Path hand = Path()
      ..moveTo(c.dx + _handTop.dx * r, c.dy + _handTop.dy * r)
      ..lineTo(c.dx, c.dy)
      ..lineTo(c.dx + _handElbowEnd.dx * r, c.dy + _handElbowEnd.dy * r);
    canvas.drawPath(hand, handPaint);

    // 节拍点
    final Paint dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = dotColor;
    canvas.drawCircle(
      Offset(c.dx + _dotCenter.dx * r, c.dy + _dotCenter.dy * r),
      r * _dotR,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(_BrandMarkPainter oldDelegate) =>
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.dotColor != dotColor;
}
