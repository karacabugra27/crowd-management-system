import 'package:flutter/material.dart';
import 'package:bluetooth_occupancy_admin/core/app_colors.dart';
import 'package:bluetooth_occupancy_admin/models/location_model.dart';

class DensityIndicator extends StatelessWidget {
  final DensityLevel level;
  final double? percentage;
  final bool showPercentage;
  final bool compact;

  const DensityIndicator({
    super.key,
    required this.level,
    this.percentage,
    this.showPercentage = false,
    this.compact = false,
  });

  /// Convenience constructor from percentage value
  factory DensityIndicator.fromPercentage(
    double percentage, {
    Key? key,
    bool showPercentage = true,
    bool compact = false,
  }) {
    final DensityLevel level;
    if (percentage >= 90) {
      level = DensityLevel.critical;
    } else if (percentage >= 75) {
      level = DensityLevel.high;
    } else if (percentage >= 50) {
      level = DensityLevel.medium;
    } else {
      level = DensityLevel.low;
    }

    return DensityIndicator(
      key: key,
      level: level,
      percentage: percentage,
      showPercentage: showPercentage,
      compact: compact,
    );
  }

  Color get _color {
    switch (level) {
      case DensityLevel.low:
        return AppColors.densityLow;
      case DensityLevel.medium:
        return AppColors.densityMedium;
      case DensityLevel.high:
        return AppColors.densityHigh;
      case DensityLevel.critical:
        return AppColors.densityCritical;
    }
  }

  String get _label {
    switch (level) {
      case DensityLevel.low:
        return 'Low';
      case DensityLevel.medium:
        return 'Medium';
      case DensityLevel.high:
        return 'High';
      case DensityLevel.critical:
        return 'Critical';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompact();
    }
    return _buildDefault();
  }

  Widget _buildDefault() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _color.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Glowing dot
          _GlowDot(color: _color, size: 8),
          const SizedBox(width: 6),
          // Label
          Text(
            _label,
            style: TextStyle(
              color: _color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          if (showPercentage && percentage != null) ...[
            const SizedBox(width: 6),
            Text(
              '${percentage!.toInt()}%',
              style: TextStyle(
                color: _color.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompact() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _GlowDot(color: _color, size: 8),
        const SizedBox(width: 5),
        Text(
          showPercentage && percentage != null
              ? '${percentage!.toInt()}%'
              : _label,
          style: TextStyle(
            color: _color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _GlowDot extends StatefulWidget {
  final Color color;
  final double size;

  const _GlowDot({
    required this.color,
    this.size = 8,
  });

  @override
  State<_GlowDot> createState() => _GlowDotState();
}

class _GlowDotState extends State<_GlowDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.3 * _animation.value),
                blurRadius: 6 * _animation.value,
                spreadRadius: 1 * _animation.value,
              ),
              BoxShadow(
                color: widget.color.withValues(alpha: 0.15 * _animation.value),
                blurRadius: 12 * _animation.value,
                spreadRadius: 2 * _animation.value,
              ),
            ],
          ),
        );
      },
    );
  }
}
