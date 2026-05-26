import 'dart:math';
import 'package:flutter/material.dart';

/// Mechanical style smoke background animation
class SmokeBackground extends StatefulWidget {
  final Widget child;
  final Color? smokeColor;
  final int particleCount;

  const SmokeBackground({
    super.key,
    required this.child,
    this.smokeColor,
    this.particleCount = 15,
  });

  @override
  State<SmokeBackground> createState() => _SmokeBackgroundState();
}

class _SmokeBackgroundState extends State<SmokeBackground>
    with TickerProviderStateMixin {
  final List<_SmokeParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initParticles();
  }

  void _initParticles() {
    for (int i = 0; i < widget.particleCount; i++) {
      _particles.add(_SmokeParticle(
        id: i,
        startX: _random.nextDouble(),
        delay: _random.nextDouble() * 5,
        duration: 8 + _random.nextDouble() * 4,
        size: 20 + _random.nextDouble() * 60,
        opacity: 0.05 + _random.nextDouble() * 0.15,
        drift: (_random.nextDouble() - 0.5) * 0.3,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dark mechanical background gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0a0a0f),
                Color(0xFF1a1a2e),
                Color(0xFF0f0f1a),
              ],
            ),
          ),
        ),
        // Smoke particle animation
        ..._particles.map((particle) => _SmokeParticleWidget(
          particle: particle,
          color: widget.smokeColor ?? const Color(0xFF4a5568),
          vsync: this,
        )),
        // Metallic overlay layer
        CustomPaint(
          painter: _MetallicOverlayPainter(),
          size: Size.infinite,
        ),
        // Content
        widget.child,
      ],
    );
  }
}

class _SmokeParticle {
  final int id;
  final double startX;
  final double delay;
  final double duration;
  final double size;
  final double opacity;
  final double drift;

  _SmokeParticle({
    required this.id,
    required this.startX,
    required this.delay,
    required this.duration,
    required this.size,
    required this.opacity,
    required this.drift,
  });
}

class _SmokeParticleWidget extends StatelessWidget {
  final _SmokeParticle particle;
  final Color color;
  final TickerProvider vsync;

  const _SmokeParticleWidget({
    required this.particle,
    required this.color,
    required this.vsync,
  });

  @override
  Widget build(BuildContext context) {
    return _SmokeParticleWidgetState(
      particle: particle,
      color: color,
      vsync: vsync,
    );
  }
}

class _SmokeParticleWidgetState extends StatefulWidget {
  final _SmokeParticle particle;
  final Color color;
  final TickerProvider vsync;

  const _SmokeParticleWidgetState({
    required this.particle,
    required this.color,
    required this.vsync,
    super.key,
  });

  @override
  State<_SmokeParticleWidgetState> createState() => _SmokeParticleWidgetStateState();
}

class _SmokeParticleWidgetStateState extends State<_SmokeParticleWidgetState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _yAnimation;
  late Animation<double> _xAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: widget.particle.duration.toInt()),
      vsync: widget.vsync,
    );

    final curve = Curves.easeInOutCubic;
    
    _yAnimation = Tween<double>(
      begin: 1.2,
      end: -0.2,
    ).animate(CurvedAnimation(parent: _controller, curve: curve));

    _xAnimation = Tween<double>(
      begin: widget.particle.startX,
      end: widget.particle.startX + widget.particle.drift,
    ).animate(CurvedAnimation(parent: _controller, curve: curve));

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: widget.particle.opacity,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    Future.delayed(Duration(milliseconds: (widget.particle.delay * 1000).toInt()), () {
      if (mounted) {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: MediaQuery.of(context).size.width * _xAnimation.value,
          top: MediaQuery.of(context).size.height * _yAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value * (0.5 + _controller.value),
            child: Container(
              width: widget.particle.size,
              height: widget.particle.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.color.withOpacity(_opacityAnimation.value),
                    widget.color.withOpacity(_opacityAnimation.value * 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Metallic overlay layer
class _MetallicOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          const Color(0xFF2a2a3e).withOpacity(0.1),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Draw fine grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF3DD6F5).withOpacity(0.03)
      ..strokeWidth = 1;

    const gridSize = 50.0;
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
