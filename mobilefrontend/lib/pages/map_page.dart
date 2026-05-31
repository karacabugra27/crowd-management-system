import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../utils/helpers.dart';
import '../widgets/common_widgets.dart';

/// Harita sayfası — web MapPage.jsx ile aynı tasarım
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _occupancyService = OccupancyService();
  final _areasService = AreasService();
  final _mapController = MapController();

  List<dynamic> _heatmap = [];
  // ignore: unused_field
  List<dynamic> _areas = [];
  bool _loading = true;
  bool _wsConnected = false;
  int? _selectedArea;
  WebSocketService? _ws;
  bool _showLegend = true;

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
        _occupancyService.heatmap(),
        _areasService.list(),
      ]);
      if (mounted) {
        setState(() {
          _heatmap = results[0];
          _areas = results[1];
          _loading = false;
        });

        // Auto-fit bounds
        _fitBounds();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fitBounds() {
    final validPoints = _heatmap
        .where((h) => h['latitude'] != null && h['longitude'] != null)
        .toList();
    if (validPoints.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(
        validPoints
            .map((p) => LatLng(
                  (p['latitude'] as num).toDouble(),
                  (p['longitude'] as num).toDouble(),
                ))
            .toList(),
      );
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _mapController.fitCamera(
            CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
          );
        }
      });
    }
  }

  void _connectWebSocket() {
    _ws = WebSocketService(
      onMessage: (msg) {
        if (mounted) {
          setState(() {
            final idx = _heatmap.indexWhere((h) => h['area_id'] == msg['area_id']);
            if (idx >= 0) {
              _heatmap[idx] = {
                ..._heatmap[idx],
                'occupancy_pct': msg['occupancy_pct'],
                'status': msg['status'],
              };
            }
          });
        }
      },
      onConnectionChange: (connected) {
        if (mounted) setState(() => _wsConnected = connected);
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
            Text('Harita yükleniyor…',
                style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    final validPoints = _heatmap
        .where((h) => h['latitude'] != null && h['longitude'] != null)
        .toList();

    // Default center: Istanbul
    final defaultCenter = LatLng(41.0082, 28.9784);
    final center = validPoints.isNotEmpty
        ? LatLng(
            (validPoints[0]['latitude'] as num).toDouble(),
            (validPoints[0]['longitude'] as num).toDouble(),
          )
        : defaultCenter;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kampüs Haritası',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Anlık doluluk — harita görünümü',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
              ConnectionStatus(connected: _wsConnected),
            ],
          ),
        ),

        // Area list (horizontal scroll)
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _heatmap.length,
            itemBuilder: (context, index) {
              final h = _heatmap[index];
              final isSelected = _selectedArea == h['area_id'];
              final color = statusColor((h['status'] as String?) ?? '');
              final pct = (h['occupancy_pct'] as num?)?.toDouble() ?? 0;

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedArea = h['area_id']);
                  if (h['latitude'] != null && h['longitude'] != null) {
                    _mapController.move(
                      LatLng(
                        (h['latitude'] as num).toDouble(),
                        (h['longitude'] as num).toDouble(),
                      ),
                      17,
                    );
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.05)
                        : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.borderHover : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        h['area_name'] ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        formatPercent(pct),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Map
        Expanded(
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 16,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                    ),
                    MarkerLayer(
                      markers: validPoints.map((point) {
                        final lat = (point['latitude'] as num).toDouble();
                        final lng = (point['longitude'] as num).toDouble();
                        final status = (point['status'] as String?) ?? '';
                        final pct = (point['occupancy_pct'] as num?)?.toDouble() ?? 0;
                        final color = statusColor(status);

                        return Marker(
                          point: LatLng(lat, lng),
                          width: 80,
                          height: 90,
                          child: GestureDetector(
                            onTap: () => _showAreaPopup(context, point),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgCard.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    '${pct.round()}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Icon(
                                  Icons.location_on,
                                  color: color,
                                  size: 36,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              // Legend
              if (_showLegend)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.layers, size: 14, color: AppColors.textDim),
                            const SizedBox(width: 6),
                            const Text(
                              'Doluluk Durumu',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDim,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(() => _showLegend = false),
                              child: const Icon(Icons.close, size: 14, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...['empty', 'low', 'medium', 'high', 'full'].map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: statusColor(s),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  statusLabel(s),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textDim,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // No geo data message
              if (validPoints.isEmpty && _heatmap.isNotEmpty)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.navigation, size: 28, color: AppColors.textMuted),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Alanların haritada görünebilmesi için konum bilgisi (latitude/longitude) eklenmelidir.',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAreaPopup(BuildContext context, dynamic point) {
    final status = (point['status'] as String?) ?? '';
    final pct = (point['occupancy_pct'] as num?)?.toDouble() ?? 0;
    final name = point['area_name'] ?? '';
    final color = statusColor(status);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StatusBadge(
                  status: status,
                  label: statusLabel(status),
                  color: color,
                  bgColor: statusBg(status),
                ),
                const SizedBox(width: 12),
                Text(
                  formatPercent(pct),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
