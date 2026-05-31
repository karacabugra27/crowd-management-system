import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/app_router.dart';
import '../models/location_model.dart';
import '../providers/location_provider.dart';
import '../widgets/map_widget.dart';
import '../widgets/stat_card.dart';
import '../widgets/density_indicator.dart';

import 'add_location_screen.dart';
import 'location_detail_screen.dart';

/// Home screen with an interactive map showing all monitoring locations.
/// Displays color-coded markers and summary statistics.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fabController;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    // Load mock data on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LocationProvider>();
      if (provider.locations.isEmpty && provider.isLoading) {
        provider.loadLocations();
      }
    });
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _onMarkerTapped(MonitoringLocation location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LocationBottomSheet(location: location),
    );
  }

  void _navigateToAddLocation() {
    Navigator.of(context).push(
      AppRouter.slideUp(const AddLocationScreen(), name: AppRouter.addLocation),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<LocationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return _buildLoadingState();
          }

          if (provider.locations.isEmpty) {
            return _buildEmptyState();
          }

          return _buildContent(provider);
        },
      ),
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(
          parent: _fabController,
          curve: Curves.elasticOut,
        ),
        child: FloatingActionButton.extended(
          onPressed: _navigateToAddLocation,
          icon: const Icon(Icons.add_location_alt_rounded),
          label: const Text('Add Base'),
          heroTag: 'add_location_fab',
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(
                AppColors.accent.withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading monitoring bases...',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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
            Text(
              'No Monitoring Bases',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first listening base to start\ntracking Bluetooth occupancy.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _navigateToAddLocation,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add First Base'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(LocationProvider provider) {
    return SafeArea(
      child: Column(
        children: [
          // ─── Header ────────────────────────────────────────
          _buildHeader(provider),

          // ─── Stats Row ─────────────────────────────────────
          _buildStatsRow(provider),

          // ─── Map ───────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border, width: 1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: MapWidget(
                    locations: provider.locations,
                    onMarkerTap: _onMarkerTapped,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(LocationProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          // App icon
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
            child: const Icon(
              Icons.bluetooth_connected_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Occupancy Monitor',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  '${provider.locations.length} active bases',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          // Notification bell (decorative)
          IconButton(
            onPressed: () {},
            icon: Stack(
              children: [
                const Icon(Icons.notifications_none_rounded,
                    color: AppColors.textSecondary),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.densityHigh,
                      shape: BoxShape.circle,
                      boxShadow: AppColors.neonGlow(AppColors.densityHigh,
                          intensity: 0.6, blurRadius: 6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(LocationProvider provider) {
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          StatCard(
            label: 'Locations',
            value: '${provider.locations.length}',
            icon: Icons.location_on_rounded,
            accentColor: AppColors.accent,
          ),
          StatCard(
            label: 'Total Devices',
            value: '${provider.totalDevices}',
            icon: Icons.bluetooth_rounded,
            accentColor: AppColors.info,
          ),
          StatCard(
            label: 'Avg. Occupancy',
            value: '${provider.averageOccupancy.toStringAsFixed(0)}%',
            icon: Icons.analytics_rounded,
            accentColor: AppColors.getDensityColor(provider.averageOccupancy),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet shown when a map marker is tapped.
class _LocationBottomSheet extends StatelessWidget {
  final MonitoringLocation location;

  const _LocationBottomSheet({required this.location});

  @override
  Widget build(BuildContext context) {
    final densityColor = AppColors.getDensityColor(location.occupancyPercentage);

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: densityColor.withValues(alpha: 0.15),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Drag handle ───────────────────────────────────
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ─── Header Row ────────────────────────────────────
            Row(
              children: [
                // Glowing status dot
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: densityColor,
                    shape: BoxShape.circle,
                    boxShadow: AppColors.neonGlow(densityColor,
                        intensity: 0.5, blurRadius: 8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    location.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                DensityIndicator.fromPercentage(location.occupancyPercentage),
              ],
            ),
            const SizedBox(height: 20),

            // ─── Stats Grid ────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.bluetooth_rounded,
                    label: 'Devices Found',
                    value: '${location.currentDeviceCount}',
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.people_rounded,
                    label: 'Full Capacity',
                    value: '${location.maxCapacity}',
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ─── Occupancy Bar ─────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Occupancy Rate',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '${location.occupancyPercentage.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: densityColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: location.occupancyPercentage / 100,
                      backgroundColor: AppColors.background,
                      valueColor: AlwaysStoppedAnimation(densityColor),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── View Details Button ───────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Close bottom sheet
                  Navigator.of(context).push(
                    AppRouter.fadeScale(
                      LocationDetailScreen(locationId: location.id),
                      name: AppRouter.locationDetail,
                    ),
                  );
                },
                icon: const Icon(Icons.visibility_rounded, size: 18),
                label: const Text('View Details & Scanning'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Small stat tile for the bottom sheet grid.
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({
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
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
