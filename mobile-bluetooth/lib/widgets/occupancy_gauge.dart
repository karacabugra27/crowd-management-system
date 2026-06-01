import 'dart:math';
import 'package:flutter/material.dart';
import 'package:crowdly_scanner/core/app_colors.dart';

class OccupancyGauge extends StatefulWidget {
  final double percentage;
  final double size;
  final String? label;

  const OccupancyGauge({
    super.key,
    required this.percentage,
    this.size = 200,
    this.label,
  });

  @override
  State<OccupancyGauge> createState() => _OccupancyGaugeState();
}

class _OccupancyGaugeState extends State<OccupancyGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: widget.percentage),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, animatedPercentage, child) {
        return AnimatedBuilder(
          animation: _glowController,
          builder: (context, _) {
            return SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // The gauge painter
                  CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _GaugePainter(
                      percentage: animatedPercentage,
                      glowValue: _glowController.value,
                      densityColor: AppColors.getDensityColor(animatedPercentage),
                      accentColor: AppColors.accent,
                    ),
                  ),
                  // Center text
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${animatedPercentage.toInt()}%',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: widget.size * 0.18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.label ?? 'Occupancy',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: widget.size * 0.065,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildDensityBadge(animatedPercentage),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDensityBadge(double percentage) {
    final color = AppColors.getDensityColor(percentage);
    final label = _getDensityLabel(percentage);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: widget.size * 0.05,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _getDensityLabel(double percentage) {
    if (percentage >= 90) return 'CRITICAL';
    if (percentage >= 75) return 'HIGH';
    if (percentage >= 50) return 'MEDIUM';
    return 'LOW';
  }
}

class _GaugePainter extends CustomPainter {
  final double percentage;
  final double glowValue;
  final Color densityColor;
  final Color accentColor;

  _GaugePainter({
    required this.percentage,
    required this.glowValue,
    required this.densityColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;
    final strokeWidth = size.width * 0.065;

    // Arc goes from 135° to 405° (270° total sweep, bottom-open gauge)
    const startAngle = 135 * pi / 180;
    const totalSweep = 270 * pi / 180;
    final fillSweep = totalSweep * (percentage / 100);

    final arcRect = Rect.fromCircle(center: center, radius: radius);

    // Draw tick marks
    _drawTickMarks(canvas, center, radius, strokeWidth);

    // Draw background track
    final trackPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, startAngle, totalSweep, false, trackPaint);

    if (percentage > 0) {
      // Draw glow behind the arc
      final glowPaint = Paint()
        ..color = densityColor.withValues(alpha: 0.12 + glowValue * 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 12
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawArc(arcRect, startAngle, fillSweep, false, glowPaint);

      // Draw the foreground arc with gradient
      final gradientPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + fillSweep,
          colors: [
            accentColor,
            Color.lerp(accentColor, densityColor, 0.5)!,
            densityColor,
          ],
          stops: const [0.0, 0.5, 1.0],
          transform: GradientRotation(0),
        ).createShader(arcRect);
      canvas.drawArc(arcRect, startAngle, fillSweep, false, gradientPaint);

      // Draw end cap glow (bright dot at end of arc)
      final endAngle = startAngle + fillSweep;
      final endX = center.dx + radius * cos(endAngle);
      final endY = center.dy + radius * sin(endAngle);
      final endPoint = Offset(endX, endY);

      final endGlowPaint = Paint()
        ..color = densityColor.withValues(alpha: 0.5 + glowValue * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(endPoint, strokeWidth * 0.6, endGlowPaint);

      final endDotPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(endPoint, strokeWidth * 0.2, endDotPaint);
    }

    // Draw inner decorative ring
    final innerRingPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(center, radius - strokeWidth * 0.8, innerRingPaint);

    // Draw outer decorative ring
    final outerRingPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(center, radius + strokeWidth * 0.8, outerRingPaint);
  }

  void _drawTickMarks(Canvas canvas, Offset center, double radius, double strokeWidth) {
    const startAngle = 135 * pi / 180;
    const totalSweep = 270 * pi / 180;
    const tickCount = 27;

    for (int i = 0; i <= tickCount; i++) {
      final angle = startAngle + (totalSweep * i / tickCount);
      final isMajor = i % 9 == 0;
      final tickLength = isMajor ? 8.0 : 4.0;
      final tickWidth = isMajor ? 1.5 : 0.8;
      final opacity = isMajor ? 0.3 : 0.15;

      final outerRadius = radius + strokeWidth * 0.8 + 4;
      final innerRadius = outerRadius + tickLength;

      final outerPoint = Offset(
        center.dx + outerRadius * cos(angle),
        center.dy + outerRadius * sin(angle),
      );
      final innerPoint = Offset(
        center.dx + innerRadius * cos(angle),
        center.dy + innerRadius * sin(angle),
      );

      final tickPaint = Paint()
        ..color = AppColors.textSecondary.withValues(alpha: opacity)
        ..strokeWidth = tickWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(outerPoint, innerPoint, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.glowValue != glowValue ||
        oldDelegate.densityColor != densityColor;
  }
}
