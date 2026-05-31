import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../utils/helpers.dart';
import '../widgets/common_widgets.dart';

/// Admin sayfası — web AdminPage.jsx ile aynı tasarım ve CRUD işlemleri
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _adminService = AdminService();
  final _areasService = AreasService();

  Map<String, dynamic>? _stats;
  List<dynamic> _areas = [];
  List<dynamic> _scanners = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    try {
      final results = await Future.wait([
        _adminService.dashboard(),
        _areasService.list(),
        _adminService.listScanners(),
      ]);
      if (mounted) {
        setState(() {
          _stats = results[0] as Map<String, dynamic>;
          _areas = results[1] as List;
          _scanners = results[2] as List;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Area CRUD ──
  Future<void> _showCreateAreaDialog() async {
    final nameCtrl = TextEditingController();
    final floorCtrl = TextEditingController();
    final capacityCtrl = TextEditingController();
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    String error = '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Yeni Alan Ekle', style: TextStyle(fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(error, style: const TextStyle(color: AppColors.red, fontSize: 13)),
                  ),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Alan Adı *', hintText: 'Ör: Kütüphane - 1. Kat'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: floorCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Kat', hintText: 'Ör: 1'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: capacityCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Kapasite *', hintText: 'Ör: 200'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Latitude', hintText: 'Ör: 41.0082'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: lngCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Longitude', hintText: 'Ör: 28.9784'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal', style: TextStyle(color: AppColors.textDim)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || capacityCtrl.text.isEmpty) {
                  setDialogState(() => error = 'Alan adı ve kapasite zorunludur.');
                  return;
                }
                try {
                  final payload = <String, dynamic>{
                    'name': nameCtrl.text,
                    'capacity': int.parse(capacityCtrl.text),
                  };
                  if (floorCtrl.text.isNotEmpty) payload['floor'] = int.parse(floorCtrl.text);
                  if (latCtrl.text.isNotEmpty) payload['latitude'] = double.parse(latCtrl.text);
                  if (lngCtrl.text.isNotEmpty) payload['longitude'] = double.parse(lngCtrl.text);
                  await _areasService.create(payload);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _fetchAll();
                } catch (e) {
                  setDialogState(() => error = cleanError(e));
                }
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Alan Oluştur'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleArea(int id) async {
    try {
      await _areasService.toggleActive(id);
      _fetchAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cleanError(e)), backgroundColor: AppColors.red),
        );
      }
    }
  }

  Future<void> _deleteArea(int id, String name) async {
    final confirmed = await _showDeleteConfirm('alan', name);
    if (confirmed == true) {
      try {
        await _areasService.deleteArea(id);
        _fetchAll();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(cleanError(e)), backgroundColor: AppColors.red),
          );
        }
      }
    }
  }

  // ── Scanner CRUD ──
  Future<void> _showCreateScannerDialog() async {
    final nameCtrl = TextEditingController();
    int? selectedAreaId;
    String error = '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Yeni Tarayıcı', style: TextStyle(fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(error, style: const TextStyle(color: AppColors.red, fontSize: 13)),
                  ),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Tarayıcı Adı *', hintText: 'Ör: Kütüphane-Scanner-01'),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.bgInput,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: selectedAreaId,
                      isExpanded: true,
                      hint: const Text('— Seçilmedi —', style: TextStyle(color: AppColors.textMuted)),
                      dropdownColor: AppColors.bgCard,
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('— Seçilmedi —')),
                        ..._areas.map((a) => DropdownMenuItem<int?>(
                              value: a['id'],
                              child: Text(a['name'] ?? ''),
                            )),
                      ],
                      onChanged: (val) => setDialogState(() => selectedAreaId = val),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal', style: TextStyle(color: AppColors.textDim)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (nameCtrl.text.isEmpty) {
                  setDialogState(() => error = 'Tarayıcı adı zorunludur.');
                  return;
                }
                try {
                  final payload = <String, dynamic>{'name': nameCtrl.text};
                  if (selectedAreaId != null) payload['area_id'] = selectedAreaId;
                  final result = await _adminService.createScanner(payload);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _fetchAll();

                  // Show API key
                  if (result.containsKey('api_key')) {
                    _showApiKeyDialog(result['api_key']);
                  }
                } catch (e) {
                  setDialogState(() => error = cleanError(e));
                }
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Tarayıcı Oluştur'),
            ),
          ],
        ),
      ),
    );
  }

  void _showApiKeyDialog(String apiKey) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Tarayıcı Oluşturuldu', style: TextStyle(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.amberDim,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.amber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bu API anahtarı yalnızca bir kez gösterilir!',
                      style: TextStyle(color: AppColors.amber, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      apiKey,
                      style: const TextStyle(
                        color: AppColors.green,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18, color: AppColors.textDim),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: apiKey));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('API anahtarı kopyalandı!'),
                          backgroundColor: AppColors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteScanner(int id, String name) async {
    final confirmed = await _showDeleteConfirm('tarayıcı', name);
    if (confirmed == true) {
      try {
        await _adminService.deleteScanner(id);
        _fetchAll();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(cleanError(e)), backgroundColor: AppColors.red),
          );
        }
      }
    }
  }

  Future<bool?> _showDeleteConfirm(String type, String name) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Silme Onayı', style: TextStyle(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 32, color: AppColors.amber),
            const SizedBox(height: 12),
            Text(
              '"$name" ${type == 'alan' ? 'alanını' : 'tarayıcısını'} silmek istediğinize emin misiniz?',
              style: const TextStyle(color: AppColors.textDim, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal', style: TextStyle(color: AppColors.textDim)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red.withValues(alpha: 0.15),
              foregroundColor: AppColors.red,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Sil'),
          ),
        ],
      ),
    );
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
            Text('Yönetim paneli yükleniyor…', style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.purple,
      backgroundColor: AppColors.bgCard,
      onRefresh: _fetchAll,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          const Row(
            children: [
              Icon(Icons.shield_outlined, size: 28, color: AppColors.purple),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Yönetim Paneli', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  Text('Alan ve tarayıcı yönetimi', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stats
          if (_stats != null)
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
                  value: '${_stats!['total_areas'] ?? 0}',
                  color: AppColors.purple,
                  bgColor: AppColors.purpleDim,
                ),
                StatCard(
                  icon: Icons.show_chart_rounded,
                  label: 'Aktif Alan',
                  value: '${_stats!['active_areas'] ?? 0}',
                  color: AppColors.blue,
                  bgColor: AppColors.blueDim,
                ),
                StatCard(
                  icon: Icons.people_outline,
                  label: 'Kullanıcılar',
                  value: '${_stats!['total_users'] ?? 0}',
                  color: AppColors.amber,
                  bgColor: AppColors.amberDim,
                ),
                StatCard(
                  icon: Icons.memory,
                  label: 'Ort. Doluluk',
                  value: formatPercent((_stats!['avg_occupancy'] as num?)?.toDouble() ?? 0),
                  color: AppColors.rose,
                  bgColor: AppColors.roseDim,
                ),
              ],
            ),
          const SizedBox(height: 28),

          // Areas section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Alanlar (${_areas.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ElevatedButton.icon(
                onPressed: _showCreateAreaDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Yeni Alan'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_areas.isEmpty)
            const EmptyState(
              icon: Icons.location_on_outlined,
              title: 'Henüz alan eklenmemiş.',
              subtitle: '',
            )
          else
            ..._areas.map((a) => _AreaListItem(
                  area: a,
                  onToggle: () => _toggleArea(a['id']),
                  onDelete: () => _deleteArea(a['id'], a['name'] ?? ''),
                )),

          const SizedBox(height: 28),

          // Scanners section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tarayıcılar (${_scanners.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ElevatedButton.icon(
                onPressed: _showCreateScannerDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Yeni Tarayıcı'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_scanners.isEmpty)
            const EmptyState(
              icon: Icons.memory,
              title: 'Henüz tarayıcı eklenmemiş.',
              subtitle: '',
            )
          else
            ..._scanners.map((s) => _ScannerListItem(
                  scanner: s,
                  onDelete: () => _deleteScanner(s['id'], s['name'] ?? '#${s['id']}'),
                )),
        ],
      ),
    );
  }
}

class _AreaListItem extends StatelessWidget {
  final dynamic area;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _AreaListItem({
    required this.area,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = area['is_active'] == true;
    final lat = area['latitude'];
    final lng = area['longitude'];

    return Opacity(
      opacity: isActive ? 1.0 : 0.5,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        area['name'] ?? '',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kat: ${area['floor'] ?? '—'} • Kapasite: ${area['capacity'] ?? '—'}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textDim),
                      ),
                      if (lat != null && lng != null)
                        Text(
                          '📍 ${(lat as num).toStringAsFixed(4)}, ${(lng as num).toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.green.withValues(alpha: 0.12)
                            : AppColors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isActive ? 'Aktif' : 'Pasif',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActive ? AppColors.green : AppColors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _IconBtn(
                  icon: isActive ? Icons.toggle_on : Icons.toggle_off,
                  color: isActive ? AppColors.green : AppColors.textMuted,
                  onTap: onToggle,
                  tooltip: isActive ? 'Pasife Al' : 'Aktifleştir',
                ),
                const SizedBox(width: 8),
                _IconBtn(
                  icon: Icons.delete_outline,
                  color: AppColors.red,
                  onTap: onDelete,
                  tooltip: 'Sil',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerListItem extends StatelessWidget {
  final dynamic scanner;
  final VoidCallback onDelete;

  const _ScannerListItem({
    required this.scanner,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = scanner['is_active'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scanner['name'] ?? '—',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Alan ID: ${scanner['area_id'] ?? '—'} • Son: ${formatDate(scanner['last_seen'])}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textDim),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.green.withValues(alpha: 0.12)
                  : AppColors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isActive ? 'Aktif' : 'Pasif',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? AppColors.green : AppColors.red,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _IconBtn(
            icon: Icons.delete_outline,
            color: AppColors.red,
            onTap: onDelete,
            tooltip: 'Sil',
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
