import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_config.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import 'login_page.dart';

/// Application settings — backend URL configuration plus an entry point to the
/// optional admin login flow.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _urlCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: context.read<ApiConfig>().baseUrl);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _urlCtrl.text.trim();
    if (!url.startsWith('http')) {
      _toast('Geçerli bir URL girin (http:// veya https:// ile başlamalı).',
          error: true);
      return;
    }
    setState(() => _saving = true);
    await context.read<ApiConfig>().setBaseUrl(url);
    if (mounted) {
      setState(() => _saving = false);
      _toast('Sunucu adresi güncellendi.');
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.red : AppColors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Ayarlar'),
        backgroundColor: AppColors.bgSidebar,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _section('Sunucu Bağlantısı',
              'Crowdly backend\'inin adresini buradan değiştirebilirsiniz.'),
          TextField(
            controller: _urlCtrl,
            decoration: InputDecoration(
              labelText: 'Backend URL',
              hintText: ApiConfig.defaultBaseUrl,
              filled: true,
              fillColor: AppColors.bgCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 8),
          Text(
            'Android emülatör: ${ApiConfig.defaultBaseUrl}\n'
            'iOS simülatör: http://127.0.0.1:8000\n'
            'Gerçek cihaz: http://<bilgisayar-ip>:8000',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          await context.read<ApiConfig>().reset();
                          _urlCtrl.text = ApiConfig.defaultBaseUrl;
                          if (mounted) _toast('Varsayılana sıfırlandı.');
                        },
                  child: const Text('Varsayılana Dön'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
                ),
              ),
            ],
          ),
          const Divider(height: 40, color: AppColors.border),
          _section('Yönetici',
              'Yönetim paneline yalnızca admin hesabı ile giriş yaparak erişebilirsiniz.'),
          if (auth.isLoggedIn && auth.isAdmin)
            _adminInfoCard(auth)
          else
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
              icon: const Icon(Icons.shield_outlined),
              label: const Text('Yönetici Girişi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bgCard,
                foregroundColor: AppColors.text,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColors.border),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _section(String title, String description) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );

  Widget _adminInfoCard(AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.purpleDim,
            ),
            child: const Icon(Icons.shield, color: AppColors.purple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auth.email ?? '—',
                  style: const TextStyle(
                      color: AppColors.text, fontWeight: FontWeight.w600),
                ),
                const Text(
                  'Yönetici olarak giriş yapıldı',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => auth.logout(),
            icon: const Icon(Icons.logout, color: AppColors.red, size: 18),
            label: const Text('Çıkış',
                style: TextStyle(color: AppColors.red, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
