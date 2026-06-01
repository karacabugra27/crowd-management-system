
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/common_widgets.dart';
import '../utils/helpers.dart';

/// Login sayfası — web LoginPage.jsx ile birebir aynı tasarım
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _error = '';
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _error = '';
      _loading = true;
    });

    final auth = context.read<AuthProvider>();
    try {
      await auth.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      // Mobile-user only exposes admin-protected views behind this form. If
      // the account isn't an admin, sign back out immediately so the rest of
      // the app keeps treating the user as a guest.
      if (!auth.isAdmin) {
        await auth.logout();
        if (mounted) {
          setState(() =>
              _error = 'Bu hesap yönetici değil. Yalnızca admin girişine izin verilir.');
        }
        return;
      }

      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = cleanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF080812),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Geri',
              )
            : null,
      ),
      body: Stack(
        children: [
          // Animated background orbs
          Positioned(
            top: -150,
            right: -100,
            child: FloatingOrb(
              size: 400,
              color: AppColors.purple,
              duration: const Duration(seconds: 12),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: FloatingOrb(
              size: 300,
              color: AppColors.gradientStart,
              duration: const Duration(seconds: 16),
              offset: const Offset(0, 0),
            ),
          ),
          Positioned(
            top: size.height * 0.4,
            left: size.width * 0.3,
            child: FloatingOrb(
              size: 200,
              color: AppColors.blue,
              duration: const Duration(seconds: 20),
            ),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: GlassCard(
                  borderRadius: 20,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Brand icon
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.purpleDim,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.show_chart_rounded,
                            size: 36,
                            color: AppColors.purple,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [AppColors.purple, AppColors.blue],
                          ).createShader(bounds),
                          child: const Text(
                            'Crowdly',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Yönetim Paneli',
                          style: TextStyle(
                            color: AppColors.textDim,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        const Text(
                          'Yönetici Girişi',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Yönetim paneline erişmek için giriş yapın',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // Error message
                        if (_error.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _error,
                              style: const TextStyle(
                                color: AppColors.red,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Email field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'E-posta',
                            hintText: 'ornek@mail.com',
                            prefixIcon: const Icon(
                              Icons.mail_outline,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Şifre',
                            hintText: '••••••••',
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Submit button
                        GradientButton(
                          loading: _loading,
                          onPressed: _handleSubmit,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.login_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Giriş Yap',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward,
                                size: 18,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        const Text(
                          'Hesap oluşturmak için sistem yöneticinizle iletişime geçin.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
