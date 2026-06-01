import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_config.dart';
import '../core/app_colors.dart';
import '../services/backend_service.dart';
import '../services/scan_uploader.dart';

/// Configuration UI for connecting this scanner to a Crowdly backend.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _baseUrlCtrl;
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _intervalCtrl;

  bool _uploadEnabled = false;
  bool _saving = false;

  // Area picker state
  List<Map<String, dynamic>> _areas = [];
  bool _loadingAreas = false;
  String? _areasError;
  int? _selectedAreaId;
  String _selectedAreaName = '';

  late BackendService _backendService;

  @override
  void initState() {
    super.initState();
    final config = context.read<ApiConfig>();
    _baseUrlCtrl = TextEditingController(text: config.baseUrl);
    _apiKeyCtrl = TextEditingController(text: config.apiKey);
    _intervalCtrl = TextEditingController(text: config.intervalSec.toString());
    _uploadEnabled = config.uploadEnabled;
    _selectedAreaId = config.areaId;
    _selectedAreaName = config.areaName;
    _backendService = BackendService(config);

    // Auto-load areas if URL is already configured
    if (config.baseUrl.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAreas());
    }
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _intervalCtrl.dispose();
    _backendService.dispose();
    super.dispose();
  }

  Future<void> _loadAreas() async {
    final url = _baseUrlCtrl.text.trim();
    if (!url.startsWith('http')) {
      setState(() => _areasError = 'Önce geçerli bir Backend URL girin.');
      return;
    }
    setState(() {
      _loadingAreas = true;
      _areasError = null;
    });
    final areas = await _backendService.fetchAreas(url);
    if (!mounted) return;
    if (areas.isEmpty) {
      setState(() {
        _loadingAreas = false;
        _areasError = 'Alan bulunamadı. URL\'i kontrol edin veya admin panelinden alan ekleyin.';
      });
    } else {
      setState(() {
        _areas = areas;
        _loadingAreas = false;
        // If previously selected area is still in list, keep it
        final stillValid = areas.any((a) => a['id'] == _selectedAreaId);
        if (!stillValid) {
          _selectedAreaId = null;
          _selectedAreaName = '';
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAreaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir alan seçin.'),
          backgroundColor: AppColors.densityHigh,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<ApiConfig>().update(
            baseUrl: _baseUrlCtrl.text,
            apiKey: _apiKeyCtrl.text,
            areaId: _selectedAreaId,
            areaName: _selectedAreaName,
            intervalSec: int.parse(_intervalCtrl.text),
            uploadEnabled: _uploadEnabled,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ayarlar kaydedildi.'),
          backgroundColor: AppColors.densityLow,
        ),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAreaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen önce bir alan seçin.'),
          backgroundColor: AppColors.densityHigh,
        ),
      );
      return;
    }
    final uploader = context.read<ScanUploader>();
    final messenger = ScaffoldMessenger.of(context);
    await context.read<ApiConfig>().update(
          baseUrl: _baseUrlCtrl.text,
          apiKey: _apiKeyCtrl.text,
          areaId: _selectedAreaId,
          areaName: _selectedAreaName,
        );
    await uploader.sendOnce();
    if (!mounted) return;
    final ok = uploader.state == UploadState.success;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Bağlantı başarılı (cihaz: ${uploader.lastDeviceCount ?? 0}).'
              : (uploader.lastError ?? 'Bağlantı başarısız.'),
        ),
        backgroundColor: ok ? AppColors.densityLow : AppColors.densityHigh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sunucu Ayarları'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _Section(
              title: 'Crowdly Backend',
              subtitle: 'Bu tarayıcının kayıtları nereye gönderileceğini belirtin.',
            ),
            _field(
              label: 'Backend URL',
              hint: 'http://10.0.2.2:8000',
              controller: _baseUrlCtrl,
              validator: (v) =>
                  (v == null || !v.startsWith('http')) ? 'Geçerli bir URL girin' : null,
            ),
            _field(
              label: 'API Anahtarı',
              hint: 'Tarayıcıya admin panelinden verilen anahtar',
              controller: _apiKeyCtrl,
              obscure: true,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'API anahtarı zorunludur' : null,
            ),
            const SizedBox(height: 4),
            // ── Area picker ──────────────────────────────────────
            const _Section(
              title: 'Tarama Alanı',
              subtitle: 'Bu cihazın Bluetooth cihazlarını sayacağı alan.',
            ),
            _AreaPicker(
              areas: _areas,
              loading: _loadingAreas,
              error: _areasError,
              selectedId: _selectedAreaId,
              onReload: _loadAreas,
              onSelected: (id, name) => setState(() {
                _selectedAreaId = id;
                _selectedAreaName = name;
              }),
            ),
            const SizedBox(height: 16),
            // ── Upload settings ──────────────────────────────────
            const _Section(
              title: 'Yükleme',
              subtitle: 'Tarama sırasında verinin sunucuya ne sıklıkta gönderileceği.',
            ),
            _field(
              label: 'Gönderme Aralığı (saniye)',
              hint: '15',
              controller: _intervalCtrl,
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return (n == null || n < 5 || n > 600)
                    ? '5 ile 600 arasında bir değer girin'
                    : null;
              },
            ),
            SwitchListTile(
              value: _uploadEnabled,
              onChanged: (v) => setState(() => _uploadEnabled = v),
              title: const Text('Otomatik Yükleme'),
              subtitle: const Text(
                'Tarama aktifken sonuçlar belirtilen aralıkla sunucuya gönderilir.',
              ),
              activeColor: AppColors.accent,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _testConnection,
                    icon: const Icon(Icons.wifi_tethering),
                    label: const Text('Bağlantıyı Test Et'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_rounded),
                    label: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _UploaderStatusCard(),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required String hint,
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: AppColors.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
        ),
        validator: validator,
      ),
    );
  }
}

// ── Area Picker Widget ──────────────────────────────────────────────

class _AreaPicker extends StatelessWidget {
  final List<Map<String, dynamic>> areas;
  final bool loading;
  final String? error;
  final int? selectedId;
  final VoidCallback onReload;
  final void Function(int id, String name) onSelected;

  const _AreaPicker({
    required this.areas,
    required this.loading,
    required this.error,
    required this.selectedId,
    required this.onReload,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Alanlar yükleniyor…',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    if (error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.densityHigh.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error!,
                style: const TextStyle(color: AppColors.densityHigh, fontSize: 13)),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onReload,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    if (areas.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Text('Alan listesi yüklenmedi.',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onReload,
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Alanları Yükle'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              dropdownColor: AppColors.surface,
              value: selectedId,
              hint: const Text('Alan seçin…',
                  style: TextStyle(color: AppColors.textSecondary)),
              items: areas.map((a) {
                final id = a['id'] as int;
                final name = a['name'] as String;
                final cap = a['capacity'] as int;
                return DropdownMenuItem<int>(
                  value: id,
                  child: Text('$name  (kapasite: $cap)',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textPrimary)),
                );
              }).toList(),
              onChanged: (id) {
                if (id == null) return;
                final area = areas.firstWhere((a) => a['id'] == id);
                onSelected(id, area['name'] as String);
              },
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onReload,
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Yenile', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header ──────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Uploader status card ────────────────────────────────────────────

class _UploaderStatusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ScanUploader>(
      builder: (context, uploader, _) {
        final color = switch (uploader.state) {
          UploadState.success => AppColors.densityLow,
          UploadState.error => AppColors.densityHigh,
          UploadState.uploading => AppColors.accent,
          UploadState.idle => AppColors.textTertiary,
        };
        final label = switch (uploader.state) {
          UploadState.success => 'Son gönderim başarılı',
          UploadState.error => 'Son gönderim başarısız',
          UploadState.uploading => 'Gönderiliyor…',
          UploadState.idle => 'Henüz gönderim yapılmadı',
        };
        return Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(label,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              if (uploader.lastError != null) ...[
                const SizedBox(height: 8),
                Text(uploader.lastError!,
                    style: const TextStyle(color: AppColors.densityHigh)),
              ],
              if (uploader.lastSyncedAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Son senkron: ${_fmt(uploader.lastSyncedAt!)}'
                  '${uploader.lastDeviceCount != null ? ' · ${uploader.lastDeviceCount} cihaz' : ''}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static String _fmt(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}
