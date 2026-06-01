import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import 'admin_page.dart';
import 'analytics_page.dart';
import 'dashboard_page.dart';
import 'map_page.dart';
import 'settings_page.dart';

/// Main app scaffold — three public pages always available, with an Admin tab
/// that appears only after a logged-in admin authenticates via the settings
/// screen. Web counterpart: `PublicLayout` + `AdminLayout` together.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isLoggedIn && auth.isAdmin;

    final pages = <Widget>[
      const DashboardPage(),
      const MapPage(),
      const AnalyticsPage(),
      if (isAdmin) const AdminPage(),
    ];

    final navItems = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.dashboard_outlined),
        activeIcon: Icon(Icons.dashboard),
        label: 'Dashboard',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.map_outlined),
        activeIcon: Icon(Icons.map),
        label: 'Harita',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.bar_chart_outlined),
        activeIcon: Icon(Icons.bar_chart),
        label: 'Analitik',
      ),
      if (isAdmin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.shield_outlined),
          activeIcon: Icon(Icons.shield),
          label: 'Yönetim',
        ),
    ];

    // If the admin signs out while standing on the Admin tab, snap back to
    // the dashboard.
    if (_currentIndex >= pages.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bgSidebar,
        title: Row(
          children: [
            const Icon(Icons.show_chart_rounded,
                color: AppColors.purple, size: 24),
            const SizedBox(width: 10),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AppColors.purple, AppColors.blue],
              ).createShader(bounds),
              child: const Text(
                'Crowdly',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Ayarlar',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined,
                color: AppColors.textMuted),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: navItems,
        ),
      ),
    );
  }
}
