import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'pages/login_page.dart';
import 'pages/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Status bar rengini koyu temaya uygun yap
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.bgSidebar,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const CrowdPulseApp());
}

class CrowdPulseApp extends StatelessWidget {
  const CrowdPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'CrowdPulse',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AuthGate(),
      ),
    );
  }
}

/// Web frontend'teki PublicRoute/ProtectedRoute mantığı
/// Kullanıcı giriş yapmışsa AppShell, yapmamışsa LoginPage gösterir
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Loading state
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
                'CrowdPulse yükleniyor…',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    // Authenticated → AppShell, otherwise → LoginPage
    if (auth.isLoggedIn) {
      return const AppShell();
    }
    return const LoginPage();
  }
}
