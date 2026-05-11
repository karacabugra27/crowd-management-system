import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../widgets/occupancy_card.dart';

class AreaDetailScreen extends StatefulWidget {
  final OccupancyData data;

  const AreaDetailScreen({super.key, required this.data});

  @override
  State<AreaDetailScreen> createState() => _AreaDetailScreenState();
}

class _AreaDetailScreenState extends State<AreaDetailScreen> {
  List<HistoryPoint> _history = [];
  bool _isLoading             = true;
  int _selectedDays           = 1;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final h = await ApiService.getHistory(widget.data.areaId, days: _selectedDays);
      if (mounted) setState(() { _history = h; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color get _areaColor => occupancyColor(widget.data.color);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060b14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0d1526),
        foregroundColor: const Color(0xFFe8f0fe),
        elevation: 0,
        title: Row(
          children: [
            Text(widget.data.icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.data.areaName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white.withOpacity(0.07)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current occupancy card (reuse widget)
            OccupancyCard(data: widget.data),

            // Chart section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day selector
                  Row(
                    children: [
                      const Text(
                        '📈 Doluluk Trendi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFe8f0fe),
                        ),
                      ),
                      const Spacer(),
                      for (final d in [1, 3, 7])
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedDays = d);
                              _loadHistory();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: _selectedDays == d
                                    ? const Color(0xFF3b82f6).withOpacity(0.2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: _selectedDays == d
                                      ? const Color(0xFF3b82f6).withOpacity(0.5)
                                      : Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Text(
                                d == 1 ? 'Bugün' : '$d Gün',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedDays == d
                                      ? const Color(0xFF3b82f6)
                                      : Colors.white.withOpacity(0.45),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Chart
                  Container(
                    height: 240,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0d1526),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.07)),
                    ),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF3b82f6)))
                        : _history.isEmpty
                            ? Center(
                                child: Text(
                                  'Henüz veri yok.\nKolektör çalıştıktan sonra görünecek.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
                                ),
                              )
                            : _buildChart(),
                  ),

                  const SizedBox(height: 24),

                  // Info cards
                  _buildInfoGrid(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    final spots = _history.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.occupancyPct);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: Colors.white.withOpacity(0.05),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, meta) => Text(
                '${v.toInt()}%',
                style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.35)),
              ),
            ),
          ),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minY: 0, maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF3b82f6),
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF3b82f6).withOpacity(0.25),
                  const Color(0xFF3b82f6).withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        // Reference lines
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(y: 80, color: const Color(0xFFef4444).withOpacity(0.4), strokeWidth: 1, dashArray: [4, 4]),
            HorizontalLine(y: 60, color: const Color(0xFFf59e0b).withOpacity(0.3), strokeWidth: 1, dashArray: [4, 4]),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGrid() {
    final items = [
      ('🏢', 'Bina', widget.data.building),
      ('👥', 'Kapasite', '${widget.data.capacity} kişi'),
      ('📡', 'Bağlı Cihaz', '${widget.data.deviceCount}'),
      ('📊', 'Durum', widget.data.status),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.5,
      children: items.map((item) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0d1526),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            Text(item.$1, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item.$2, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.4))),
                  Text(item.$3, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFe8f0fe))),
                ],
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }
}
