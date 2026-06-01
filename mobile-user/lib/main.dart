import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/api_config.dart';
import 'core/theme.dart';
import 'pages/app_shell.dart';
import 'providers/auth_provider.dart';
import 'services/api_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.bgSidebar,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Restore the persisted backend URL before any HTTP client tries to use it.
  final apiConfig = ApiConfig();
  await apiConfig.load();
  ApiClient.bindDefaultConfig(apiConfig);

  runApp(CrowdlyApp(apiConfig: apiConfig));
}

/// Root widget — the user-facing pages are public, so the app always lands on
/// the [AppShell]. The admin tab (and the /admin features behind it) only
/// appears once an admin signs in from the settings screen.
class CrowdlyApp extends StatelessWidget {
  const CrowdlyApp({super.key, required this.apiConfig});

  final ApiConfig apiConfig;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ApiConfig>.value(value: apiConfig),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Crowdly',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const _Bootstrapper(),
      ),
    );
  }
}

/// Brief splash while [AuthProvider] resolves any persisted admin session.
/// We do not gate access to public pages on the auth result — only the admin
/// tab visibility depends on it.
class _Bootstrapper extends StatelessWidget {
  const _Bootstrapper();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.loading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.purple),
              SizedBox(height: 16),
              Text(
                'Crowdly yükleniyor…',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return const AppShell();
  }
}
