import 'dart:math';
import 'package:flutter/material.dart';
import 'package:bluetooth_occupancy_admin/core/app_colors.dart';

class RadarWidget extends StatefulWidget {
  final bool isScanning;
  final int deviceCount;
  final double size;

  const RadarWidget({
    super.key,
    required this.isScanning,
    this.deviceCount = 0,
    this.size = 250,
  });

  @override
  State<RadarWidget> createState() => _RadarWidgetState();
}

class _RadarWidgetState extends State<RadarWidget>
    with TickerProviderStateMixin {
  late AnimationController _sweepController;
  late AnimationController _pulseController;
  late AnimationController _dotPulseController;
  final List<_DeviceDot> _dots = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _dotPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    if (widget.isScanning) {
      _sweepController.repeat();
    }

    _generateDots();
  }

  @override
  void didUpdateWidget(covariant RadarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isScanning && !oldWidget.isScanning) {
      _sweepController.repeat();
    } else if (!widget.isScanning && oldWidget.isScanning) {
      _sweepController.stop();
    }

    if (widget.deviceCount != oldWidget.deviceCount) {
      _generateDots();
    }
  }

  void _generateDots() {
    _dots.clear();
    final center = widget.size / 2;
    final maxRadius = center * 0.85;

    for (int i = 0; i < widget.deviceCount; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final distance = _random.nextDouble() * maxRadius * 0.7 + maxRadius * 0.15;
      _dots.add(_DeviceDot(
        x: center + cos(angle) * distance,
        y: center + sin(angle) * distance,
        pulseOffset: _random.nextDouble(),
        radius: 3.0 + _random.nextDouble() * 2.0,
      ));
    }
  }

  @override
  void dispose() {
    _sweepController.dispose();
    _pulseController.dispose();
    _dotPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _sweepController,
          _pulseController,
          _dotPulseController,
        ]),
        builder: (context, child) {
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _RadarPainter(
              sweepAngle: _sweepController.value * 2 * pi,
              pulseValue: _pulseController.value,
              dotPulseValue: _dotPulseController.value,
              isScanning: widget.isScanning,
              dots: _dots,
              accentColor: AppColors.accent,
            ),
          );
        },
      ),
    );
  }
}

class _DeviceDot {
  final double x;
  final double y;
  final double pulseOffset;
  final double radius;

  _DeviceDot({
    required this.x,
    required this.y,
    required this.pulseOffset,
    required this.radius,
  });
}

class _RadarPainter extends CustomPainter {
  final double sweepAngle;
  final double pulseValue;
  final double dotPulseValue;
  final bool isScanning;
  final List<_DeviceDot> dots;
  final Color accentColor;

  _RadarPainter({
    required this.sweepAngle,
    required this.pulseValue,
    required this.dotPulseValue,
    required this.isScanning,
    required this.dots,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw background
    final bgPaint = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxRadius, bgPaint);

    // Draw outer border glow
    final outerGlowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.15 + pulseValue * 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8);
    canvas.drawCircle(center, maxRadius - 1, outerGlowPaint);

    // Draw concentric rings
    final ringCount = 4;
    for (int i = 1; i <= ringCount; i++) {
      final ratio = i / ringCount;
      final radius = maxRadius * ratio;
      final opacity = 0.08 + (i == ringCount ? 0.12 : 0.0);

      final ringPaint = Paint()
        ..color = accentColor.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(center, radius, ringPaint);
    }

    // Draw crosshairs
    final crossPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.06)
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius),
      Offset(center.dx, center.dy + maxRadius),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx - maxRadius, center.dy),
      Offset(center.dx + maxRadius, center.dy),
      crossPaint,
    );

    // Draw diagonal crosshairs
    final diagLength = maxRadius * 0.707;
    canvas.drawLine(
      Offset(center.dx - diagLength, center.dy - diagLength),
      Offset(center.dx + diagLength, center.dy + diagLength),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx + diagLength, center.dy - diagLength),
      Offset(center.dx - diagLength, center.dy + diagLength),
      crossPaint,
    );

    // Draw sweep line with gradient trail
    if (isScanning) {
      _drawSweep(canvas, center, maxRadius);
    }

    // Draw center dot
    final centerDotGlow = Paint()
      ..color = accentColor.withValues(alpha: 0.4 + pulseValue * 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center, 5, centerDotGlow);

    final centerDotPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3, centerDotPaint);

    // Draw device dots
    for (final dot in dots) {
      _drawDeviceDot(canvas, dot);
    }

    // Draw outer ring
    final outerRingPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, maxRadius - 1, outerRingPaint);
  }

  void _drawSweep(Canvas canvas, Offset center, double maxRadius) {
    // Sweep gradient trail (cone shape)
    const sweepSpan = 0.6; // radians of the trail
    final sweepRect = Rect.fromCircle(center: center, radius: maxRadius * 0.95);

    final sweepGradient = SweepGradient(
      startAngle: sweepAngle - sweepSpan,
      endAngle: sweepAngle,
      colors: [
        accentColor.withValues(alpha: 0.0),
        accentColor.withValues(alpha: 0.03),
        accentColor.withValues(alpha: 0.08),
        accentColor.withValues(alpha: 0.18),
      ],
      stops: const [0.0, 0.3, 0.7, 1.0],
      transform: GradientRotation(0),
    );

    final sweepPaint = Paint()
      ..shader = sweepGradient.createShader(sweepRect)
      ..style = PaintingStyle.fill;

    // Draw the sweep as a filled arc
    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        sweepRect,
        sweepAngle - sweepSpan,
        sweepSpan,
        false,
      )
      ..close();
    canvas.drawPath(path, sweepPaint);

    // Draw the sweep line itself
    final lineEnd = Offset(
      center.dx + cos(sweepAngle) * maxRadius * 0.95,
      center.dy + sin(sweepAngle) * maxRadius * 0.95,
    );

    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          accentColor.withValues(alpha: 0.8),
          accentColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromPoints(center, lineEnd))
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, lineEnd, linePaint);
  }

  void _drawDeviceDot(Canvas canvas, _DeviceDot dot) {
    final offsetPulse = (dotPulseValue + dot.pulseOffset) % 1.0;
    final glowSize = dot.radius + 4 + offsetPulse * 4;

    // Outer glow
    final glowPaint = Paint()
      ..color = AppColors.densityLow.withValues(alpha: 0.15 + offsetPulse * 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(dot.x, dot.y), glowSize, glowPaint);

    // Middle glow
    final midGlowPaint = Paint()
      ..color = AppColors.densityLow.withValues(alpha: 0.3 + offsetPulse * 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(dot.x, dot.y), dot.radius + 2, midGlowPaint);

    // Core dot
    final dotPaint = Paint()
      ..color = AppColors.densityLow.withValues(alpha: 0.8 + offsetPulse * 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(dot.x, dot.y), dot.radius, dotPaint);

    // Bright center
    final brightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6 + offsetPulse * 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(dot.x, dot.y), dot.radius * 0.4, brightPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => true;
}
