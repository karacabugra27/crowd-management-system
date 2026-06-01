import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_config.dart';
import '../core/app_colors.dart';
import '../providers/location_provider.dart';
import '../services/scan_uploader.dart';
import '../widgets/occupancy_gauge.dart';
import '../widgets/density_indicator.dart';
import 'settings_screen.dart';

/// Home screen: shows the configured area's live occupancy status.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer3<ApiConfig, LocationProvider, ScanUploader>(
          builder: (context, config, provider, uploader, _) {
            return Column(
              children: [
                _Header(config: config),
                Expanded(
                  child: config.isComplete
                      ? _ScanView(config: config, provider: provider, uploader: uploader)
                      : _SetupPrompt(onSettings: () => _openSettings(context)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final ApiConfig config;
  const _Header({required this.config});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.accent, AppColors.accent.withValues(alpha: 0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.bluetooth_connected_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Crowdly Tarayıcı',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  config.areaName.isNotEmpty ? config.areaName : 'Alan seçilmedi',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sunucu ayarları',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings_rounded, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Setup prompt (shown when not configured) ─────────────────────────

class _SetupPrompt extends StatelessWidget {
  final VoidCallback onSettings;
  const _SetupPrompt({required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bluetooth_searching_rounded,
                size: 64,
                color: AppColors.accent.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Yapılandırma Gerekli',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Taramaya başlamak için backend URL, API anahtarı ve alan seçmelisiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onSettings,
              icon: const Icon(Icons.settings_rounded),
              label: const Text('Ayarları Aç'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scan view (shown when configured) ───────────────────────────────

class _ScanView extends StatelessWidget {
  final ApiConfig config;
  final LocationProvider provider;
  final ScanUploader uploader;

  const _ScanView({
    required this.config,
    required this.provider,
    required this.uploader,
  });

  @override
  Widget build(BuildContext context) {
    final occupancyPct = uploader.lastOccupancyPct ?? 0.0;
    final statusText = _statusLabel(uploader.lastStatus);
    final statusColor = AppColors.getDensityColor(occupancyPct);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Occupancy gauge card ────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.08),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                OccupancyGauge(
                  percentage: occupancyPct,
                  size: 180,
                  label: statusText,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DensityIndicator.fromPercentage(occupancyPct),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Stats row ───────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Canlı Cihaz',
                  value: '${provider.liveDeviceCount}',
                  icon: Icons.bluetooth_rounded,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Son Yükleme',
                  value: uploader.lastDeviceCount != null
                      ? '${uploader.lastDeviceCount}'
                      : '—',
                  icon: Icons.cloud_upload_rounded,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Kapasite',
                  value: '${config.areaId != null ? '?' : '—'}',
                  icon: Icons.people_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Uploader status ─────────────────────────────────────
          _UploaderCard(uploader: uploader),
          const SizedBox(height: 20),

          // ── Scan toggle button ──────────────────────────────────
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () async {
                if (provider.isScanning) {
                  await provider.stopScanning();
                } else {
                  await provider.startScanning();
                }
              },
              icon: Icon(
                provider.isScanning
                    ? Icons.stop_rounded
                    : Icons.play_arrow_rounded,
              ),
              label: Text(
                provider.isScanning ? 'Taramayı Durdur' : 'Taramayı Başlat',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    provider.isScanning ? AppColors.densityHigh : AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(String? s) {
    return switch (s) {
      'empty' => 'Boş',
      'low' => 'Az Yoğun',
      'medium' => 'Orta',
      'high' => 'Yoğun',
      'full' => 'Dolu',
      _ => 'Veri Bekleniyor',
    };
  }
}

// ── Uploader status card ─────────────────────────────────────────────

class _UploaderCard extends StatelessWidget {
  final ScanUploader uploader;
  const _UploaderCard({required this.uploader});

  @override
  Widget build(BuildContext context) {
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
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
            const SizedBox(height: 6),
            Text(uploader.lastError!,
                style: const TextStyle(
                    color: AppColors.densityHigh, fontSize: 12)),
          ],
          if (uploader.lastSyncedAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Son senkron: ${_fmt(uploader.lastSyncedAt!)}'
              '${uploader.lastDeviceCount != null ? ' · ${uploader.lastDeviceCount} cihaz algılandı' : ''}',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  static String _fmt(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

// ── Small stat tile ──────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
