import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/occupancy_card.dart';
import 'area_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<OccupancyData> _data    = [];
  bool _isLoading              = true;
  String? _error;
  Timer? _refreshTimer;
  DateTime? _lastUpdate;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Auto-refresh every 30s
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final data = await ApiService.getLiveOccupancy();
      if (mounted) {
        setState(() {
          _data       = data;
          _isLoading  = false;
          _error      = null;
          _lastUpdate = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error     = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String get _avgOccupancy {
    if (_data.isEmpty) return '—';
    final avg = _data.map((d) => d.occupancyPct).reduce((a, b) => a + b) / _data.length;
    return '${avg.toStringAsFixed(0)}%';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060b14),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_data.isNotEmpty) _buildSummaryRow(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF3b82f6)))
                  : _error != null
                      ? _buildError()
                      : _buildList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          const Text('🏫', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CampusPulse',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFe8f0fe),
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  _lastUpdate != null
                      ? 'Son güncelleme: ${_lastUpdate!.hour.toString().padLeft(2,'0')}:${_lastUpdate!.minute.toString().padLeft(2,'0')}'
                      : 'Yükleniyor...',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4)),
                ),
              ],
            ),
          ),
          // Live indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF10b981).withOpacity(0.12),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: const Color(0xFF10b981).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(color: Color(0xFF10b981), shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                const Text('CANLI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10b981))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF8ba3c7)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    final empty  = _data.where((d) => d.color == 'green').length;
    final medium = _data.where((d) => d.color == 'yellow').length;
    final full   = _data.where((d) => d.color == 'orange' || d.color == 'red').length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _buildStatChip('Ort. Dol.', _avgOccupancy, const Color(0xFF3b82f6)),
          const SizedBox(width: 8),
          _buildStatChip('Boş', '$empty', const Color(0xFF10b981)),
          const SizedBox(width: 8),
          _buildStatChip('Orta', '$medium', const Color(0xFFf59e0b)),
          const SizedBox(width: 8),
          _buildStatChip('Dolu', '$full', const Color(0xFFef4444)),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.45))),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 16),
            const Text(
              'Sunucuya bağlanılamadı',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFe8f0fe)),
            ),
            const SizedBox(height: 8),
            Text(
              'Backend\'in çalıştığından emin ol:\npython backend/main.py',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.45)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3b82f6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Yeniden Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF3b82f6),
      backgroundColor: const Color(0xFF0d1526),
      child: ListView.builder(
        itemCount: _data.length,
        padding: const EdgeInsets.only(bottom: 24),
        itemBuilder: (context, i) => OccupancyCard(
          data: _data[i],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AreaDetailScreen(data: _data[i]),
            ),
          ),
        ),
      ),
    );
  }
}
