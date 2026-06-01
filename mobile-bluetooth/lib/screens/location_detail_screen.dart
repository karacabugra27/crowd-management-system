import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../models/location_model.dart';
import '../providers/location_provider.dart';
import '../widgets/radar_widget.dart';
import '../widgets/occupancy_gauge.dart';
import '../widgets/density_indicator.dart';

/// Detailed view for a single monitoring location.
/// Shows live scanning animation, real-time stats, and a device discovery log.
class LocationDetailScreen extends StatefulWidget {
  final String locationId;

  const LocationDetailScreen({super.key, required this.locationId});

  @override
  State<LocationDetailScreen> createState() => _LocationDetailScreenState();
}

class _LocationDetailScreenState extends State<LocationDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _fadeIn = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.1, 0.8, curve: Curves.easeOutCubic),
    ));
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Scanning toggle in appbar
          Consumer<LocationProvider>(
            builder: (context, provider, _) {
              final location = provider.getLocation(widget.locationId);
              if (location == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: () {
                    if (location.isScanning) {
                      provider.stopScanning(widget.locationId);
                    } else {
                      provider.startScanning(widget.locationId);
                    }
                  },
                  icon: Icon(
                    location.isScanning
                        ? Icons.pause_circle_rounded
                        : Icons.play_circle_rounded,
                    color: location.isScanning
                        ? AppColors.warning
                        : AppColors.success,
                    size: 28,
                  ),
                  tooltip: location.isScanning ? 'Pause Scanning' : 'Start Scanning',
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<LocationProvider>(
        builder: (context, provider, _) {
          final location = provider.getLocation(widget.locationId);

          if (location == null) {
            return _buildErrorState();
          }

          return FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideIn,
              child: _buildContent(context, provider, location),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 64, color: AppColors.error.withValues(alpha: 0.6)),
          const SizedBox(height: 16),
          Text(
            'Location Not Found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'This monitoring base may have been removed.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, LocationProvider provider, MonitoringLocation location) {
    final densityColor = AppColors.getDensityColor(location.occupancyPercentage);
    final devices = provider.getDiscoveredDevices(location.id);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Location Header ─────────────────────────────────
          _buildLocationHeader(location, densityColor),
          const SizedBox(height: 20),

          // ─── Radar & Gauge Row ───────────────────────────────
          _buildRadarAndGauge(location),
          const SizedBox(height: 20),

          // ─── Stats Cards ─────────────────────────────────────
          _buildStatsCards(location, densityColor),
          const SizedBox(height: 20),

          // ─── Scanning Status ─────────────────────────────────
          _buildScanningToggle(location, provider),
          const SizedBox(height: 20),

          // ─── Discovery Log ───────────────────────────────────
          _buildDiscoveryLog(devices, location.isScanning),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLocationHeader(MonitoringLocation location, Color densityColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            densityColor.withValues(alpha: 0.08),
            AppColors.card,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: densityColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          // Glowing status indicator
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: densityColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              boxShadow: AppColors.neonGlow(
                  densityColor, intensity: 0.3, blurRadius: 12),
            ),
            child: Icon(
              location.isScanning
                  ? Icons.sensors_rounded
                  : Icons.sensors_off_rounded,
              color: densityColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    DensityIndicator.fromPercentage(
                      location.occupancyPercentage,
                      showPercentage: true,
                      compact: true,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${location.latitude.toStringAsFixed(3)}°N, ${location.longitude.toStringAsFixed(3)}°E',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarAndGauge(MonitoringLocation location) {
    return Row(
      children: [
        // Radar animation
        Expanded(
          flex: 5,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: RadarWidget(
                isScanning: location.isScanning,
                deviceCount: location.currentDeviceCount,
                size: 180,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Occupancy gauge
        Expanded(
          flex: 4,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.all(12),
            child: OccupancyGauge(
              percentage: location.occupancyPercentage,
              size: 130,
              label: 'Occupancy',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards(MonitoringLocation location, Color densityColor) {
    return Row(
      children: [
        Expanded(
          child: _DetailStatCard(
            icon: Icons.bluetooth_rounded,
            label: 'Found Devices',
            value: '${location.currentDeviceCount}',
            color: AppColors.info,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DetailStatCard(
            icon: Icons.people_rounded,
            label: 'Capacity',
            value: '${location.currentDeviceCount} / ${location.maxCapacity}',
            color: densityColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DetailStatCard(
            icon: Icons.speed_rounded,
            label: 'Rate',
            value: '${location.occupancyPercentage.toStringAsFixed(0)}%',
            color: densityColor,
          ),
        ),
      ],
    );
  }

  Widget _buildScanningToggle(
      MonitoringLocation location, LocationProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: location.isScanning
              ? AppColors.success.withValues(alpha: 0.2)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          // Animated scanning indicator
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: location.isScanning ? AppColors.success : AppColors.textTertiary,
              shape: BoxShape.circle,
              boxShadow: location.isScanning
                  ? AppColors.neonGlow(AppColors.success,
                      intensity: 0.5, blurRadius: 8)
                  : [],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.isScanning
                      ? 'Bluetooth Scanning Active'
                      : 'Scanning Paused',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: location.isScanning
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  location.isScanning
                      ? 'Listening for nearby devices...'
                      : 'Tap to resume scanning',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          // Toggle button
          ElevatedButton(
            onPressed: () {
              if (location.isScanning) {
                provider.stopScanning(widget.locationId);
              } else {
                provider.startScanning(widget.locationId);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: location.isScanning
                  ? AppColors.error.withValues(alpha: 0.15)
                  : AppColors.success.withValues(alpha: 0.15),
              foregroundColor:
                  location.isScanning ? AppColors.error : AppColors.success,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: Text(location.isScanning ? 'Stop' : 'Start'),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveryLog(List<DiscoveredDevice> devices, bool isScanning) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Discovery Log',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Spacer(),
            if (isScanning)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor:
                          AlwaysStoppedAnimation(AppColors.accent.withValues(alpha: 0.7)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Live',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (devices.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.device_hub_rounded,
                      color: AppColors.textTertiary, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    isScanning
                        ? 'Waiting for device discoveries...'
                        : 'Start scanning to discover devices',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: devices.length.clamp(0, 15),
                separatorBuilder: (context2, index2) => Divider(
                  height: 1,
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
                itemBuilder: (context, index) {
                  final device = devices[index];
                  return _DeviceLogEntry(
                    device: device,
                    isNew: index == 0 && isScanning,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// Small stat card used within the detail screen.
class _DetailStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DetailStatCard({
    required this.icon,
    required this.label,
    required this.value,
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
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }
}

/// A single entry in the device discovery log.
class _DeviceLogEntry extends StatelessWidget {
  final DiscoveredDevice device;
  final bool isNew;

  const _DeviceLogEntry({
    required this.device,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      color: isNew ? AppColors.accent.withValues(alpha: 0.06) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Signal strength indicator
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _rssiColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.bluetooth_rounded, color: _rssiColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 13,
                      ),
                ),
                Text(
                  device.macAddress,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                ),
              ],
            ),
          ),
          // RSSI badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _rssiColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${device.rssi} dBm',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _rssiColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Time
          Text(
            _formatTime(device.discoveredAt),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                ),
          ),
        ],
      ),
    );
  }

  Color get _rssiColor {
    if (device.rssi > -50) return AppColors.success;
    if (device.rssi > -70) return AppColors.warning;
    return AppColors.error;
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}
