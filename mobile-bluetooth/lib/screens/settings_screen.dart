import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_config.dart';
import '../core/app_colors.dart';
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
  late final TextEditingController _areaIdCtrl;
  late final TextEditingController _intervalCtrl;
  bool _uploadEnabled = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final config = context.read<ApiConfig>();
    _baseUrlCtrl = TextEditingController(text: config.baseUrl);
    _apiKeyCtrl = TextEditingController(text: config.apiKey);
    _areaIdCtrl = TextEditingController(text: config.areaId?.toString() ?? '');
    _intervalCtrl = TextEditingController(text: config.intervalSec.toString());
    _uploadEnabled = config.uploadEnabled;
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _areaIdCtrl.dispose();
    _intervalCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<ApiConfig>().update(
            baseUrl: _baseUrlCtrl.text,
            apiKey: _apiKeyCtrl.text,
            areaId: int.parse(_areaIdCtrl.text),
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
    final uploader = context.read<ScanUploader>();
    final messenger = ScaffoldMessenger.of(context);
    await context.read<ApiConfig>().update(
          baseUrl: _baseUrlCtrl.text,
          apiKey: _apiKeyCtrl.text,
          areaId: int.parse(_areaIdCtrl.text),
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
              subtitle:
                  'Bu tarayıcının kayıtları nereye gönderileceğini belirtin.',
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
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'API anahtarı zorunludur'
                  : null,
            ),
            _field(
              label: 'Alan ID',
              hint: 'Bu cihazın okuyacağı alanın ID değeri',
              controller: _areaIdCtrl,
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return (n == null || n <= 0) ? 'Pozitif bir sayı girin' : null;
              },
            ),
            const SizedBox(height: 12),
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
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

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
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
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
                  'Son senkron: ${_formatTime(uploader.lastSyncedAt!)}'
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

  static String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}
