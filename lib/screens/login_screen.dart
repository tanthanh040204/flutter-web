// @file       login_screen.dart
// @brief      Screen UI for Login.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';

/* Public classes ----------------------------------------------------- */
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/* Private classes ---------------------------------------------------- */
class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeCodeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _employeeCodeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      employeeCode: _employeeCodeCtrl.text,
      password: _passwordCtrl.text,
    );

    if (!mounted) return;

    if (!ok && auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final language = context.watch<LanguageProvider>();
    final isCompact = MediaQuery.of(context).size.width < 860;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _LoginBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: isCompact
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _LoginIntroPanel(compact: true),
                            const SizedBox(height: 18),
                            _LoginFormCard(
                              auth: auth,
                              language: language,
                              formKey: _formKey,
                              employeeCodeCtrl: _employeeCodeCtrl,
                              passwordCtrl: _passwordCtrl,
                              obscurePassword: _obscurePassword,
                              onTogglePassword: () => setState(() {
                                _obscurePassword = !_obscurePassword;
                              }),
                              onSubmit: _submit,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            const Expanded(
                              flex: 10,
                              child: _LoginIntroPanel(),
                            ),
                            const SizedBox(width: 28),
                            Expanded(
                              flex: 8,
                              child: _LoginFormCard(
                                auth: auth,
                                language: language,
                                formKey: _formKey,
                                employeeCodeCtrl: _employeeCodeCtrl,
                                passwordCtrl: _passwordCtrl,
                                obscurePassword: _obscurePassword,
                                onTogglePassword: () => setState(() {
                                  _obscurePassword = !_obscurePassword;
                                }),
                                onSubmit: _submit,
                              ),
                            ),
                          ],
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

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7FCFF), Color(0xFFE8F6FF), Color(0xFFFFFFFF)],
        ),
      ),
      child: CustomPaint(
        painter: _LoginBackgroundPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _LoginBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final navy = Paint()..color = AppColors.navy.withOpacity(0.10);
    final blue = Paint()..color = AppColors.primary.withOpacity(0.08);
    final green = Paint()..color = AppColors.accent.withOpacity(0.08);

    canvas.drawCircle(Offset(size.width * 0.06, size.height * 0.12), 170, navy);
    canvas.drawCircle(Offset(size.width * 0.92, size.height * 0.18), 140, blue);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.88), 210, green);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LoginIntroPanel extends StatelessWidget {
  const _LoginIntroPanel({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 24 : 34),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF073B5E), Color(0xFF075985), Color(0xFF0B78B6)],
        ),
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.26),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.20)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.electric_moped_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'UTE Electric Vehicles',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 18 : 36),
          Text(
            context.tr(
              'Quản lý xe điện thông minh, gọn gàng và trực quan.',
              'Smart, clean and visual electric vehicle management.',
            ),
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 28 : 38,
              height: 1.12,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr(
              'Theo dõi trạng thái mở khóa, lộ trình, bảo trì và thông tin thuê xe trong cùng một màn hình quản trị.',
              'Monitor lock state, routes, maintenance and rental users in one admin dashboard.',
            ),
            style: const TextStyle(
              color: Color(0xFFD9F5FF),
              fontSize: 15.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _FeatureChip(
                icon: Icons.speed_rounded,
                text: context.tr('Realtime', 'Realtime'),
              ),
              _FeatureChip(
                icon: Icons.route_rounded,
                text: context.tr('Lộ trình', 'Routes'),
              ),
              _FeatureChip(
                icon: Icons.shield_rounded,
                text: context.tr('An toàn', 'Safety'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFB8F7D2), size: 18),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginFormCard extends StatelessWidget {
  const _LoginFormCard({
    required this.auth,
    required this.language,
    required this.formKey,
    required this.employeeCodeCtrl,
    required this.passwordCtrl,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  final AuthProvider auth;
  final LanguageProvider language;
  final GlobalKey<FormState> formKey;
  final TextEditingController employeeCodeCtrl;
  final TextEditingController passwordCtrl;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: const Color(0xFFE2EEF7)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.14),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.read<LanguageProvider>().toggle(),
                icon: const Icon(Icons.translate_outlined, size: 18),
                label: Text(language.isVietnamese ? 'English' : 'Tiếng Việt'),
              ),
            ),
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.lock_open_rounded, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('Đăng nhập hệ thống', 'System Login'),
              style: const TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w900,
                color: AppColors.dark,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'Nhập mã nhân viên và mật khẩu để vào trang quản trị.',
                'Enter your employee code and password to access the dashboard.',
              ),
              style: const TextStyle(
                color: AppColors.gray600,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 26),
            TextFormField(
              controller: employeeCodeCtrl,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: context.tr('Mã nhân viên', 'Employee Code'),
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.tr(
                    'Vui lòng nhập mã nhân viên.',
                    'Please enter your employee code.',
                  );
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: passwordCtrl,
              obscureText: obscurePassword,
              onFieldSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                labelText: context.tr('Mật khẩu', 'Password'),
                prefixIcon: const Icon(Icons.password_outlined),
                suffixIcon: IconButton(
                  onPressed: onTogglePassword,
                  icon: Icon(
                    obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.tr(
                    'Vui lòng nhập mật khẩu.',
                    'Please enter your password.',
                  );
                }
                return null;
              },
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: auth.isLoading ? null : onSubmit,
                icon: auth.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.login_rounded),
                label: Text(context.tr('Đăng nhập', 'Login')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* End of file -------------------------------------------------------- */
