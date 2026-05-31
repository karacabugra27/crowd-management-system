import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Maps color string from API to Flutter Color
Color occupancyColor(String color) {
  switch (color) {
    case 'green':  return const Color(0xFF10b981);
    case 'yellow': return const Color(0xFFf59e0b);
    case 'orange': return const Color(0xFFf97316);
    case 'red':    return const Color(0xFFef4444);
    default:       return Colors.grey;
  }
}

/// Animated occupancy card widget
class OccupancyCard extends StatelessWidget {
  final OccupancyData data;
  final VoidCallback? onTap;

  const OccupancyCard({super.key, required this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color  = occupancyColor(data.color);
    final pct    = data.occupancyPct;
    final bgColor = color.withOpacity(0.08);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0d1526),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Text(data.icon, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.areaName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFe8f0fe),
                          ),
                        ),
                        Text(
                          data.building,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Text(
                      data.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Percentage
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 10),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: pct / 100),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Footer meta
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '👥 ${data.deviceCount} / ${data.capacity} cihaz',
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4)),
                  ),
                  Text(
                    '🕐 ${_formatTime(data.lastUpdated)}',
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2,'0')}:'
        '${local.minute.toString().padLeft(2,'0')}:'
        '${local.second.toString().padLeft(2,'0')}';
  }
}
