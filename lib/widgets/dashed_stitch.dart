import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable Fabric Cutting Stitch Motif
/// Mimics sewing cutting lines, tailor tacking, and garment swing tags.

/// Horizontal or Vertical Dashed Line Divider
class DashedDivider extends StatelessWidget {
  final Axis direction;
  final double dashLength;
  final double dashGap;
  final double strokeWidth;
  final Color color;

  const DashedDivider({
    super.key,
    this.direction = Axis.horizontal,
    this.dashLength = 5.0,
    this.dashGap = 4.0,
    this.strokeWidth = 1.2,
    this.color = AppTheme.greenSoft,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedLinePainter(
        direction: direction,
        dashLength: dashLength,
        dashGap: dashGap,
        strokeWidth: strokeWidth,
        color: color,
      ),
      size: direction == Axis.horizontal
          ? Size(double.infinity, strokeWidth)
          : Size(strokeWidth, double.infinity),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Axis direction;
  final double dashLength;
  final double dashGap;
  final double strokeWidth;
  final Color color;

  _DashedLinePainter({
    required this.direction,
    required this.dashLength,
    required this.dashGap,
    required this.strokeWidth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (direction == Axis.horizontal) {
      double startX = 0;
      final y = size.height / 2;
      while (startX < size.width) {
        final endX = math.min(startX + dashLength, size.width);
        canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
        startX += dashLength + dashGap;
      }
    } else {
      double startY = 0;
      final x = size.width / 2;
      while (startY < size.height) {
        final endY = math.min(startY + dashLength, size.height);
        canvas.drawLine(Offset(x, startY), Offset(x, endY), paint);
        startY += dashLength + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      color != oldDelegate.color ||
      dashLength != oldDelegate.dashLength ||
      dashGap != oldDelegate.dashGap ||
      strokeWidth != oldDelegate.strokeWidth;
}

/// Dashed Circle Painter (used for the coin placement guide)
class DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dashCount;
  final double dashRatio; // Proportion of dash vs gap (e.g. 0.6)

  DashedCirclePainter({
    this.color = AppTheme.thread,
    this.strokeWidth = 2.0,
    this.dashCount = 36,
    this.dashRatio = 0.55,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final totalAngle = 2 * math.pi;
    final sweepPerDash = totalAngle / dashCount;
    final activeAngle = sweepPerDash * dashRatio;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * sweepPerDash;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        activeAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(DashedCirclePainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      dashCount != oldDelegate.dashCount;
}

/// Card Container with Dashed Bottom Edge
class DashedBottomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Gradient? gradient;
  final double borderRadius;
  final Color dashColor;

  const DashedBottomCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.gradient,
    this.borderRadius = 16,
    this.dashColor = AppTheme.greenSoft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? (backgroundColor ?? AppTheme.cream) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppTheme.greenSoft.withOpacity(0.2), width: 1),
      ),
      child: Stack(
        children: [
          Padding(
            padding: padding,
            child: child,
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 0,
            child: DashedDivider(
              direction: Axis.horizontal,
              dashLength: 6,
              dashGap: 4,
              strokeWidth: 1.5,
              color: dashColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Main Hero "Swing Tag" Card
/// Looks like an authentic garment swing tag:
/// - Dark green gradient fill (greenDeep -> greenMid)
/// - Punch-hole circle in the top-left corner
/// - Dashed cream-colored line along the bottom edge
class SwingTagCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SwingTagCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(22, 26, 22, 24),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppTheme.heroCardGradient,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.greenDeep.withOpacity(0.18),
            offset: const Offset(0, 8),
            blurRadius: 20,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Garment Swing-Tag Punch Hole in Top-Left Corner
          Positioned(
            top: 14,
            left: 16,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.mintTop, // mimics revealing the background underneath
                border: Border.all(
                  color: AppTheme.cream.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    offset: const Offset(0.5, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),

          // Main Card Content
          Padding(
            padding: padding,
            child: child,
          ),

          // Dashed Cream Cutting Line along Bottom Edge
          Positioned(
            left: 20,
            right: 20,
            bottom: 6,
            child: DashedDivider(
              direction: Axis.horizontal,
              dashLength: 6.5,
              dashGap: 4.5,
              strokeWidth: 1.6,
              color: AppTheme.cream.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtle Diagonal Striped Background for Viewfinder Placeholder
class DiagonalStripeBackground extends StatelessWidget {
  final Widget? child;
  const DiagonalStripeBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DiagonalStripePainter(),
      child: child,
    );
  }
}

class _DiagonalStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Soft base color
    final bgPaint = Paint()..color = const Color(0xFF1E2F24);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final linePaint = Paint()
      ..color = AppTheme.greenSoft.withOpacity(0.12)
      ..strokeWidth = 1.0;

    const step = 20.0;
    for (double x = -size.height; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

/// Corner Brackets for Viewfinder Camera Framing Guide
class ViewfinderCornerBrackets extends StatelessWidget {
  final double cornerLength;
  final double strokeWidth;
  final Color color;

  const ViewfinderCornerBrackets({
    super.key,
    this.cornerLength = 26.0,
    this.strokeWidth = 2.5,
    this.color = AppTheme.cream,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ViewfinderCornersPainter(
        cornerLength: cornerLength,
        strokeWidth: strokeWidth,
        color: color,
      ),
      size: Size.infinite,
    );
  }
}

class _ViewfinderCornersPainter extends CustomPainter {
  final double cornerLength;
  final double strokeWidth;
  final Color color;

  _ViewfinderCornersPainter({
    required this.cornerLength,
    required this.strokeWidth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final l = cornerLength;

    // Top-Left Corner
    final pathTL = Path()
      ..moveTo(0, l)
      ..lineTo(0, 0)
      ..lineTo(l, 0);
    canvas.drawPath(pathTL, paint);

    // Top-Right Corner
    final pathTR = Path()
      ..moveTo(w - l, 0)
      ..lineTo(w, 0)
      ..lineTo(w, l);
    canvas.drawPath(pathTR, paint);

    // Bottom-Left Corner
    final pathBL = Path()
      ..moveTo(0, h - l)
      ..lineTo(0, h)
      ..lineTo(l, h);
    canvas.drawPath(pathBL, paint);

    // Bottom-Right Corner
    final pathBR = Path()
      ..moveTo(w - l, h)
      ..lineTo(w, h)
      ..lineTo(w, h - l);
    canvas.drawPath(pathBR, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
