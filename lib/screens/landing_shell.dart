// @file       landing_shell.dart
// @brief      Outer welcome screen before entering the existing login/app flow.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';

import '../config/app_string.dart';
import 'app_bootstrap.dart';

/* Public classes ----------------------------------------------------- */
class LandingShell extends StatefulWidget {
  const LandingShell({super.key});

  @override
  State<LandingShell> createState() => _LandingShellState();
}

/* Private classes ---------------------------------------------------- */
class _LandingShellState extends State<LandingShell> {
  bool _enteredApp = false;

  @override
  Widget build(BuildContext context) {
    if (_enteredApp) {
      return const AppBootstrap();
    }

    return _WelcomeLandingScreen(
      onLoginPressed: () => setState(() => _enteredApp = true),
    );
  }
}

class _WelcomeLandingScreen extends StatefulWidget {
  const _WelcomeLandingScreen({required this.onLoginPressed});

  final VoidCallback onLoginPressed;

  @override
  State<_WelcomeLandingScreen> createState() => _WelcomeLandingScreenState();
}

class _WelcomeLandingScreenState extends State<_WelcomeLandingScreen> {

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 760;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _LandingBackground()),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 18 : 34,
                vertical: isCompact ? 16 : 22,
              ),
              child: Column(
                children: [
                  _TopBar(onLoginPressed: widget.onLoginPressed),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: isCompact
                            ? const _CompactContent()
                            : const _WideContent(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onLoginPressed});

  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B4D78).withOpacity(0.14),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pedal_bike, color: Color(0xFF0A5B8F), size: 22),
              SizedBox(width: 8),
              Text(
                AppStrings.brandName,
                style: TextStyle(
                  color: Color(0xFF073B5E),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: onLoginPressed,
          icon: const Icon(Icons.login_rounded, size: 20),
          label: const Text('Đăng nhập'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0B5F93),
            foregroundColor: Colors.white,
            elevation: 8,
            shadowColor: const Color(0xFF0B5F93).withOpacity(0.34),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}

class _WideContent extends StatelessWidget {
  const _WideContent();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          flex: 11,
          child: _HeroCard(),
        ),
        const SizedBox(width: 34),
        const Expanded(
          flex: 9,
          child: _MessagePanel(),
        ),
      ],
    );
  }
}

class _CompactContent extends StatelessWidget {
  const _CompactContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HeroCard(),
          const SizedBox(height: 22),
          _MessagePanel(),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Colors.white, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A4770).withOpacity(0.18),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      const Color(0xFFEAF7FF).withOpacity(0.85),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 44),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: Color(0x1A0A5B8F),
                    child: Icon(
                      Icons.pedal_bike,
                      size: 64,
                      color: Color(0xFF0A5B8F),
                    ),
                  ),
                  SizedBox(height: 18),
                  Text(
                    'UTE',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF073B5E),
                      letterSpacing: 3,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'BICYCLES',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0A5B8F),
                      letterSpacing: 5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 26),
      decoration: BoxDecoration(
        color: const Color(0xFF073B5E).withOpacity(0.92),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF062F4C).withOpacity(0.28),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WelcomeBadge(),
          SizedBox(height: 22),
          Text(
            'Chúc bạn có 1 ngày làm việc vui vẻ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              height: 1.18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 16),
          _MessageLine(
            icon: Icons.bolt_rounded,
            text: 'Cống hiến hết mình cho công ty nhé',
          ),
          SizedBox(height: 12),
          _MessageLine(
            icon: Icons.edit_note_rounded,
            text: 'Lưu ý: hãy ghi chú thông tin dữ liệu của từng xe trước khi tan ca!',
          ),
          SizedBox(height: 22),
          Text(
            'Theo dõi dữ liệu, kiểm tra trạng thái xe và bàn giao thông tin đầy đủ trước khi kết thúc ca làm việc.',
            style: TextStyle(
              color: Color(0xFFD9F1FF),
              fontSize: 15.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeBadge extends StatelessWidget {
  const _WelcomeBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF7ED6FF).withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF7ED6FF).withOpacity(0.34)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, color: Color(0xFF9FE6FF), size: 18),
          SizedBox(width: 8),
          Text(
            AppStrings.brandSystemVi,
            style: TextStyle(
              color: Color(0xFFE9FAFF),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageLine extends StatelessWidget {
  const _MessageLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF9FE6FF), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingBackground extends StatelessWidget {
  const _LandingBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF7FCFF),
            Color(0xFFE7F5FF),
            Color(0xFFFFFFFF),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _LandingBackgroundPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _LandingBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final darkBlue = Paint()..color = const Color(0xFF004B78);
    final midBlue = Paint()..color = const Color(0xFF0B86C8).withOpacity(0.12);
    final lightBlue = Paint()..color = const Color(0xFF39B8F2).withOpacity(0.16);

    final topShape = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.32, 0)
      ..lineTo(0, size.height * 0.36)
      ..close();
    canvas.drawPath(topShape, darkBlue);

    final bottomShape = Path()
      ..moveTo(size.width, size.height)
      ..lineTo(size.width * 0.78, size.height)
      ..lineTo(size.width, size.height * 0.72)
      ..close();
    canvas.drawPath(bottomShape, lightBlue);

    final accentShape = Path()
      ..moveTo(size.width * 0.78, size.height * 0.78)
      ..lineTo(size.width * 0.91, size.height * 0.66)
      ..lineTo(size.width * 0.94, size.height * 0.72)
      ..lineTo(size.width * 0.82, size.height * 0.84)
      ..close();
    canvas.drawPath(accentShape, midBlue);

    final circlePaint = Paint()..color = const Color(0xFF0B5F93).withOpacity(0.05);
    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.82),
      size.shortestSide * 0.18,
      circlePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.93, size.height * 0.18),
      size.shortestSide * 0.13,
      circlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


/* End of file -------------------------------------------------------- */
