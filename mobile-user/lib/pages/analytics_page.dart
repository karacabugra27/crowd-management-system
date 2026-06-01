import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../utils/helpers.dart';
import '../widgets/common_widgets.dart';

/// Analitik sayfası — web AnalyticsPage.jsx ile aynı tasarım
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final _areasService = AreasService();
  final _occupancyService = OccupancyService();

  List<dynamic> _areas = [];
  int? _selectedArea;
  int _hours = 24;
  List<dynamic> _history = [];
  List<dynamic> _summary = [];
  bool _loading = true;
  bool _historyLoading = false;

  final _hourOptions = [
    {'value': 1, 'label': 'Son 1 Saat'},
    {'value': 6, 'label': 'Son 6 Saat'},
    {'value': 12, 'label': 'Son 12 Saat'},
    {'value': 24, 'label': 'Son 24 Saat'},
    {'value': 72, 'label': 'Son 3 Gün'},
    {'value': 168, 'label': 'Son 1 Hafta'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchAreas();
  }

  Future<void> _fetchAreas() async {
    try {
      final areas = await _areasService.list();
      if (mounted) {
        setState(() {
          _areas = areas;
          if (areas.isNotEmpty && _selectedArea == null) {
            _selectedArea = areas[0]['id'];
          }
          _loading = false;
        });
        _fetchHistory();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchHistory() async {
    if (_selectedArea == null) return;
    setState(() => _historyLoading = true);
    try {
      final results = await Future.wait([
        _occupancyService.history(_selectedArea!, hours: _hours),
        _occupancyService.summary(),
      ]);
      if (mounted) {
        setState(() {
          _history = (results[0]).reversed.toList();
          _summary = results[1];
          _historyLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  Map<String, dynamic>? get _areaSummary {
    if (_selectedArea == null) return null;
    for (final s in _summary) {
      if (s['area_id'].toString() == _selectedArea.toString()) {
        return s as Map<String, dynamic>;
      }
    }
    return null;
  }

  String get _areaName {
    if (_selectedArea == null) return '';
    final area = _areas.firstWhere(
      (a) => a['id'] == _selectedArea,
      orElse: () => null,
    );
    return area?['name'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.purple),
            SizedBox(height: 16),
            Text('Yükleniyor…', style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analitik',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 4),
            Text(
              'Geçmiş doluluk verileri ve trendler',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Filters
        Row(
          children: [
            // Area selector
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.filter_list, size: 16, color: AppColors.textDim),
                      SizedBox(width: 6),
                      Text(
                        'Alan',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.bgInput,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedArea,
                        isExpanded: true,
                        dropdownColor: AppColors.bgCard,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                        ),
                        items: _areas.map((a) {
                          return DropdownMenuItem<int>(
                            value: a['id'],
                            child: Text(a['name'] ?? ''),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedArea = val);
                          _fetchHistory();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Hours selector
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: AppColors.textDim),
                      SizedBox(width: 6),
                      Text(
                        'Süre',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.bgInput,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _hours,
                        isExpanded: true,
                        dropdownColor: AppColors.bgCard,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                        ),
                        items: _hourOptions.map((opt) {
                          return DropdownMenuItem<int>(
                            value: opt['value'] as int,
                            child: Text(opt['label'] as String),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _hours = val!);
                          _fetchHistory();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Summary cards
        if (_areaSummary != null) ...[
          Row(
            children: [
              Expanded(
                child: _AnalyticsStat(
                  icon: Icons.trending_up_rounded,
                  label: 'Ort. Doluluk',
                  value: formatPercent(
                    (_areaSummary!['avg_occupancy'] as num?)?.toDouble() ?? 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AnalyticsStat(
                  icon: Icons.bar_chart_rounded,
                  label: 'Maks. Doluluk',
                  value: formatPercent(
                    (_areaSummary!['max_occupancy'] as num?)?.toDouble() ?? 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AnalyticsStat(
                  icon: Icons.access_time,
                  label: 'Pik Saati',
                  value: _areaSummary!['peak_hour'] != null
                      ? '${_areaSummary!['peak_hour'].toString().padLeft(2, '0')}:00'
                      : '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],

        // Occupancy chart
        if (_historyLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: Column(
                children: [
                  CircularProgressIndicator(color: AppColors.purple),
                  SizedBox(height: 16),
                  Text('Geçmiş veriler yükleniyor…',
                      style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
          )
        else if (_history.isEmpty)
          const EmptyState(
            icon: Icons.bar_chart_rounded,
            title: 'Bu dönem için veri yok',
            subtitle: 'Seçili dönemde doluluk kaydı bulunmuyor.',
          )
        else ...[
          // Occupancy trend chart
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_areaName — Doluluk Trendi ($_hours saat)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 250,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.white.withValues(alpha: 0.06),
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) => Text(
                              '${value.toInt()}%',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: (_history.length / 6).ceilToDouble().clamp(1, double.infinity),
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx >= 0 && idx < _history.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    formatTime(_history[idx]['recorded_at']),
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      minY: 0,
                      maxY: 100,
                      lineBarsData: [
                        LineChartBarData(
                          spots: _history.asMap().entries.map((e) {
                            final pct = (e.value['occupancy_pct'] as num?)?.toDouble() ?? 0;
                            return FlSpot(e.key.toDouble(), pct);
                          }).toList(),
                          isCurved: true,
                          color: AppColors.purple,
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.purple.withValues(alpha: 0.4),
                                AppColors.purple.withValues(alpha: 0.05),
                              ],
                            ),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => const Color(0xFF1E1E2E),
                          getTooltipItems: (spots) {
                            return spots.map((spot) {
                              return LineTooltipItem(
                                '${spot.y.round()}%',
                                const TextStyle(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Device count chart
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cihaz Sayısı',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.white.withValues(alpha: 0.06),
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            getTitlesWidget: (value, meta) => Text(
                              '${value.toInt()}',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: (_history.length / 6).ceilToDouble().clamp(1, double.infinity),
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx >= 0 && idx < _history.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    formatTime(_history[idx]['recorded_at']),
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: _history.asMap().entries.map((e) {
                        final devices = (e.value['device_count'] as num?)?.toDouble() ?? 0;
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: devices,
                              color: AppColors.gradientStart,
                              width: (_history.length > 30) ? 4 : 12,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => const Color(0xFF1E1E2E),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${rod.toY.toInt()} cihaz',
                              const TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AnalyticsStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AnalyticsStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.purple),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
