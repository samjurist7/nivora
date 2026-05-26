import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../services/user_service.dart';
import '../theme/mechanical_theme.dart';
import '../widgets/smoke_background.dart';
import 'login_page.dart';
import 'choose_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _glowController;
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _rotationController.repeat();
    _glowController.repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _scaleController.forward();
      }
    });

    // Splash page displays for 2.5 seconds then navigates based on login state
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      final userService = Provider.of<UserService>(context, listen: false);
      final nextPage = userService.hasValidToken()
          ? const ChoosePage()
          : const LoginPage();
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => nextPage,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _glowController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SmokeBackground(
      smokeColor: const Color(0xFF3DD6F5),
      particleCount: 12,
      child: SafeArea(
        child: Stack(
          children: [
            // Background grid decoration
            CustomPaint(
              painter: _GridPatternPainter(),
              size: Size.infinite,
            ),
            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  // Mechanical ring decoration
                  _buildMechanicalRings(),
                  const SizedBox(height: 40),
                  // Logo and text
                  _buildLogoSection(),
                  const SizedBox(height: 20),
                  // Loading indicator
                  _buildLoadingIndicator(),
                  const Spacer(),
                  // Bottom decoration
                  _buildBottomDecoration(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMechanicalRings() {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationController.value * 2 * math.pi,
                child: CustomPaint(
                  size: const Size(280, 280),
                  painter: _GearRingPainter(
                    color: MechanicalTheme.primaryCyan.withOpacity(0.4),
                    radius: 140,
                    gearCount: 16,
                  ),
                ),
              );
            },
          ),
          // Inner ring - counter rotation
          AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: -_rotationController.value * 2 * math.pi * 0.5,
                child: CustomPaint(
                  size: const Size(200, 200),
                  painter: _GearRingPainter(
                    color: MechanicalTheme.heatOrange.withOpacity(0.5),
                    radius: 100,
                    gearCount: 12,
                  ),
                ),
              );
            },
          ),
          // Center glow
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Container(
                width: 120 * (0.8 + 0.2 * _glowController.value),
                height: 120 * (0.8 + 0.2 * _glowController.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      MechanicalTheme.primaryCyan.withOpacity(0.3 * _glowController.value),
                      MechanicalTheme.primaryCyan.withOpacity(0.1 * _glowController.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSection() {
    return FadeTransition(
      opacity: _scaleController,
      child: ScaleTransition(
        scale: _scaleController,
        child: Column(
          children: [
            // Logo icon container
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    MechanicalTheme.bgLight,
                    MechanicalTheme.bgDark,
                  ],
                ),
                border: Border.all(
                  color: MechanicalTheme.primaryCyan,
                  width: 2,
                ),
                boxShadow: MechanicalTheme.createGlowShadow(MechanicalTheme.primaryCyan),
              ),
              child: Center(
                child: Icon(
                  Icons.settings,
                  size: 50,
                  color: MechanicalTheme.primaryCyan.withOpacity(0.8),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Brand name
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [MechanicalTheme.primaryCyan, MechanicalTheme.coolGreen],
              ).createShader(bounds),
              child: const Text(
                'ShishaX',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 8,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'PRECISION HEATING',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: MechanicalTheme.textSecondary,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: SizedBox(
        width: 60,
        height: 6,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: MechanicalTheme.bgLight,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: MechanicalTheme.primaryCyan.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                return Positioned(
                  left: _glowController.value * 54,
                  child: Container(
                    width: 20,
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [MechanicalTheme.primaryCyan, MechanicalTheme.coolGreen],
                      ),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: MechanicalTheme.createGlowShadow(MechanicalTheme.primaryCyan),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomDecoration() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildDecorativeLine(60),
        const SizedBox(width: 20),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: MechanicalTheme.primaryCyan.withOpacity(0.5),
            boxShadow: MechanicalTheme.createGlowShadow(MechanicalTheme.primaryCyan),
          ),
        ),
        const SizedBox(width: 20),
        _buildDecorativeLine(60),
      ],
    );
  }

  Widget _buildDecorativeLine(double width) {
    return Container(
      width: width,
      height: 2,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MechanicalTheme.primaryCyan, Colors.transparent],
        ),
      ),
    );
  }
}

/// Gear ring painter
class _GearRingPainter extends CustomPainter {
  final Color color;
  final double radius;
  final int gearCount;

  _GearRingPainter({
    required this.color,
    required this.radius,
    required this.gearCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);

    // Draw gears
    for (int i = 0; i < gearCount; i++) {
      final angle = (2 * math.pi / gearCount) * i;
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;

      canvas.drawCircle(Offset(x, y), 5, paint);
    }

    // Draw connecting ring
    paint.strokeWidth = 1;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _GearRingPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.gearCount != gearCount;
  }
}

/// Grid pattern painter
class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MechanicalTheme.primaryCyan.withOpacity(0.03)
      ..strokeWidth = 1;

    const gridSize = 40.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Corner decorations
    final cornerPaint = Paint()
      ..color = MechanicalTheme.primaryCyan.withOpacity(0.1)
      ..strokeWidth = 2;

    const cornerLength = 30.0;
    const offset = 20.0;

    // Top left
    canvas.drawLine(Offset(offset, offset), Offset(offset + cornerLength, offset), cornerPaint);
    canvas.drawLine(Offset(offset, offset), Offset(offset, offset + cornerLength), cornerPaint);

    // Top right
    canvas.drawLine(Offset(size.width - offset, offset), Offset(size.width - offset - cornerLength, offset), cornerPaint);
    canvas.drawLine(Offset(size.width - offset, offset), Offset(size.width - offset, offset + cornerLength), cornerPaint);

    // Bottom left
    canvas.drawLine(Offset(offset, size.height - offset), Offset(offset + cornerLength, size.height - offset), cornerPaint);
    canvas.drawLine(Offset(offset, size.height - offset), Offset(offset, size.height - offset - cornerLength), cornerPaint);

    // Bottom right
    canvas.drawLine(Offset(size.width - offset, size.height - offset), Offset(size.width - offset - cornerLength, size.height - offset), cornerPaint);
    canvas.drawLine(Offset(size.width - offset, size.height - offset), Offset(size.width - offset, size.height - offset - cornerLength), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
