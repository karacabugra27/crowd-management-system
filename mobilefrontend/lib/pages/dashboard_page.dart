import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../utils/helpers.dart';
import '../widgets/common_widgets.dart';

/// Dashboard sayfası — web DashboardPage.jsx ile aynı tasarım ve veri
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _occupancyService = OccupancyService();
  List<dynamic> _liveData = [];
  List<dynamic> _summary = [];
  bool _loading = true;
  bool _wsConnected = false;
  WebSocketService? _ws;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _ws?.disconnect();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final results = await Future.wait([
        _occupancyService.live(),
        _occupancyService.summary(),
      ]);
      if (mounted) {
        setState(() {
          _liveData = results[0];
          _summary = results[1];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _connectWebSocket() {
    _ws = WebSocketService(
      onMessage: (msg) {
        if (mounted) {
          setState(() {
            if (msg['type'] == 'occupancy.live' && msg['data'] is List) {
              _liveData = List<dynamic>.from(msg['data']);
            } else if (msg['type'] == 'occupancy_update' && msg['data'] != null) {
              final data = msg['data'];
              final items = data is List ? data : [data];
              for (var item in items) {
                final idx = _liveData.indexWhere(
                  (a) => a['area_id'] == item['area_id'],
                );
                final updated = {
                  'area_id': item['area_id'],
                  'area_name': item['area_name'] ?? item['name'],
                  'device_count': item['device_count'],
                  'occupancy_pct': item['occupancy_pct'],
                  'status': item['status'],
                  'last_updated': item['last_updated'] ?? item['timestamp'],
                };
                if (idx >= 0) {
                  _liveData[idx] = updated;
                } else {
                  _liveData.add(updated);
                }
              }
            }
          });
        }
      },
      onConnectionChange: (connected) {
        if (mounted) {
          setState(() => _wsConnected = connected);
        }
      },
    );
    _ws!.connect();
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
            Text(
              'Veriler yükleniyor…',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    final totalAreas = _liveData.length;
    final totalDevices = _liveData.fold<int>(
      0,
      (sum, a) => sum + ((a['device_count'] as num?)?.toInt() ?? 0),
    );
    final avgOccupancy = totalAreas > 0
        ? _liveData.fold<double>(
              0,
              (sum, a) => sum + ((a['occupancy_pct'] as num?)?.toDouble() ?? 0),
            ) /
            totalAreas
        : 0.0;

    Map<String, dynamic>? busiestArea;
    if (_liveData.isNotEmpty) {
      busiestArea = _liveData.reduce((max, a) =>
          ((a['occupancy_pct'] as num?)?.toDouble() ?? 0) >
                  ((max['occupancy_pct'] as num?)?.toDouble() ?? 0)
              ? a
              : max);
    }

    return RefreshIndicator(
      color: AppColors.purple,
      backgroundColor: AppColors.bgCard,
      onRefresh: _fetchData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Kampüs doluluk durumu — anlık görünüm',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              ConnectionStatus(connected: _wsConnected),
            ],
          ),
          const SizedBox(height: 24),

          // Stat cards grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              StatCard(
                icon: Icons.location_on_outlined,
                label: 'Toplam Alan',
                value: '$totalAreas',
                color: AppColors.purple,
                bgColor: AppColors.purpleDim,
              ),
              StatCard(
                icon: Icons.people_outline,
                label: 'Algılanan Cihaz',
                value: '$totalDevices',
                color: AppColors.blue,
                bgColor: AppColors.blueDim,
              ),
              StatCard(
                icon: Icons.trending_up_rounded,
                label: 'Ort. Doluluk',
                value: formatPercent(avgOccupancy),
                color: AppColors.amber,
                bgColor: AppColors.amberDim,
              ),
              StatCard(
                icon: Icons.show_chart_rounded,
                label: 'En Yoğun',
                value: busiestArea?['area_name'] ?? '—',
                color: AppColors.rose,
                bgColor: AppColors.roseDim,
                smallValue: true,
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Live occupancy section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Canlı Doluluk',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  // Navigate to map
                  DefaultTabController.of(context);
                },
                icon: const Text(
                  'Haritada Gör',
                  style: TextStyle(
                    color: AppColors.purple,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                label: const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppColors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_liveData.isEmpty)
            const EmptyState(
              icon: Icons.location_on_outlined,
              title: 'Henüz alan verisi yok',
              subtitle: 'Yönetim panelinden alan ekleyerek başlayın.',
            )
          else
            ..._liveData.map((area) => _AreaCard(area: area)),

          // Summary table
          if (_summary.isNotEmpty) ...[
            const SizedBox(height: 28),
            const Text(
              'Alan Özet İstatistikleri',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      Colors.white.withValues(alpha: 0.02),
                    ),
                    columns: const [
                      DataColumn(label: Text('Alan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted))),
                      DataColumn(label: Text('Ort.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted))),
                      DataColumn(label: Text('Maks.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted))),
                      DataColumn(label: Text('Pik', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted))),
                      DataColumn(label: Text('Kayıt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted))),
                    ],
                    rows: _summary.map((s) {
                      final peakHour = s['peak_hour'];
                      return DataRow(cells: [
                        DataCell(Text(s['area_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                        DataCell(Text(formatPercent((s['avg_occupancy'] as num?)?.toDouble() ?? 0))),
                        DataCell(Text(formatPercent((s['max_occupancy'] as num?)?.toDouble() ?? 0))),
                        DataCell(Text(peakHour != null ? '${peakHour.toString().padLeft(2, '0')}:00' : '—')),
                        DataCell(Text('${s['total_records'] ?? 0}')),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Area card widget (dashboard'daki doluluk kartı)
class _AreaCard extends StatelessWidget {
  final dynamic area;

  const _AreaCard({required this.area});

  @override
  Widget build(BuildContext context) {
    final status = (area['status'] as String?) ?? 'empty';
    final occupancyPct = (area['occupancy_pct'] as num?)?.toDouble() ?? 0;
    final deviceCount = (area['device_count'] as num?)?.toInt() ?? 0;
    final areaName = area['area_name'] ?? '';
    final lastUpdated = area['last_updated'] as String?;
    final color = statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  areaName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusBadge(
                status: status,
                label: statusLabel(status),
                color: color,
                bgColor: statusBg(status),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Body
          Row(
            children: [
              OccupancyRing(percent: occupancyPct, color: color),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.people_outline,
                            size: 14, color: AppColors.textDim),
                        const SizedBox(width: 6),
                        Text(
                          '$deviceCount cihaz',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textDim,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 14, color: AppColors.textDim),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            formatDate(lastUpdated),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textDim,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
