import 'dart:math';
import 'package:flutter/material.dart';

/// Mechanical style heating device animation component
class HeatingDeviceAnimation extends StatefulWidget {
  final bool isHeating;
  final int currentTemp;
  final int targetTemp;
  final Color? primaryColor;

  const HeatingDeviceAnimation({
    super.key,
    required this.isHeating,
    required this.currentTemp,
    this.targetTemp = 200,
    this.primaryColor,
  });

  @override
  State<HeatingDeviceAnimation> createState() => _HeatingDeviceAnimationState();
}

class _HeatingDeviceAnimationState extends State<HeatingDeviceAnimation>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _heatWaveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _heatWaveAnimation;

  @override
  void initState() {
    super.initState();
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _heatWaveController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _heatWaveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _heatWaveController, curve: Curves.easeInOut),
    );

    if (widget.isHeating) {
      _rotationController.repeat();
      _pulseController.repeat(reverse: true);
      _heatWaveController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(HeatingDeviceAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHeating != oldWidget.isHeating) {
      if (widget.isHeating) {
        _rotationController.repeat();
        _pulseController.repeat(reverse: true);
        _heatWaveController.repeat(reverse: true);
      } else {
        _rotationController.stop();
        _pulseController.stop();
        _heatWaveController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _heatWaveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.primaryColor ?? const Color(0xFFFF6B35);
    final heatIntensity = widget.currentTemp / 300.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer mechanical ring
        _buildOuterRing(color),

        // Rotating gear ring
        AnimatedBuilder(
          animation: _rotationController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotationController.value * 2 * pi,
              child: _buildGearRing(color),
            );
          },
        ),

        // Pulsing glow
        if (widget.isHeating)
          ScaleTransition(
            scale: _pulseAnimation,
            child: _buildHeatGlow(color, heatIntensity),
          ),

        // Heat wave effect
        if (widget.isHeating)
          _buildHeatWaves(color),

        // Center device body
        _buildDeviceBody(color, heatIntensity),

        // Temperature display
        _buildTemperatureDisplay(heatIntensity),
      ],
    );
  }

  Widget _buildOuterRing(Color color) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
    );
  }

  Widget _buildGearRing(Color color) {
    return CustomPaint(
      size: const Size(260, 260),
      painter: _GearRingPainter(
        color: color.withOpacity(0.6),
        gearCount: 12,
      ),
    );
  }

  Widget _buildHeatGlow(Color color, double intensity) {
    return Container(
      width: 200 * (0.8 + intensity * 0.4),
      height: 200 * (0.8 + intensity * 0.4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.3 * intensity),
            color.withOpacity(0.1 * intensity),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildHeatWaves(Color color) {
    return AnimatedBuilder(
      animation: _heatWaveController,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(300, 300),
          painter: _HeatWavePainter(
            color: color.withOpacity(0.4),
            waveOffset: _heatWaveAnimation.value,
          ),
        );
      },
    );
  }

  Widget _buildDeviceBody(Color color, double intensity) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2a2a3e),
            const Color(0xFF1a1a2e),
            color.withOpacity(0.3 * intensity),
          ],
        ),
        border: Border.all(
          color: color.withOpacity(0.5 + intensity * 0.5),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3 * intensity),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.settings,
          size: 60,
          color: color.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildTemperatureDisplay(double intensity) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${widget.currentTemp}°C',
          style: TextStyle(
            color: widget.isHeating 
                ? const Color(0xFFFF6B35) 
                : Colors.white.withOpacity(0.7),
            fontSize: 32,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: const Color(0xFFFF6B35).withOpacity(intensity * 0.8),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        if (widget.isHeating)
          Text(
            'HEATING',
            style: TextStyle(
              color: const Color(0xFFFF6B35),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
      ],
    );
  }
}

/// Gear ring painter
class _GearRingPainter extends CustomPainter {
  final Color color;
  final int gearCount;

  _GearRingPainter({required this.color, required this.gearCount});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    for (int i = 0; i < gearCount; i++) {
      final angle = (2 * pi / gearCount) * i;
      final x = center.dx + cos(angle) * radius;
      final y = center.dy + sin(angle) * radius;

      canvas.drawCircle(Offset(x, y), 8, paint);
    }

    // Inner ring
    paint.strokeWidth = 2;
    canvas.drawCircle(center, radius - 20, paint);
  }

  @override
  bool shouldRepaint(covariant _GearRingPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Heat wave painter
class _HeatWavePainter extends CustomPainter {
  final Color color;
  final double waveOffset;

  _HeatWavePainter({required this.color, required this.waveOffset});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < 3; i++) {
      final progress = (waveOffset + i / 3) % 1.0;
      final radius = 80 + progress * 100;
      final alpha = 1.0 - progress;

      paint.color = color.withOpacity(alpha * 0.4);

      // Draw wavy ring
      final path = Path();
      for (double angle = 0; angle < 2 * pi; angle += 0.1) {
        final waveRadius = radius + sin(angle * 8 + waveOffset * 2 * pi) * 5;
        final x = center.dx + cos(angle) * waveRadius;
        final y = center.dy + sin(angle) * waveRadius;
        if (angle == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeatWavePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.waveOffset != waveOffset;
  }
}

/// Mechanical style decorative border
class MechanicalBorder extends StatelessWidget {
  final Widget child;
  final Color? color;
  final double borderRadius;
  final double borderWidth;

  const MechanicalBorder({
    super.key,
    required this.child,
    this.color,
    this.borderRadius = 12,
    this.borderWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = color ?? const Color(0xFF3DD6F5);
    
    return Stack(
      children: [
        // Outer glow
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: borderColor.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        // Main border
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor.withOpacity(0.5),
              width: borderWidth,
            ),
          ),
          child: child,
        ),
        // Corner decoration
        CustomPaint(
          painter: _CornerDecoratorPainter(color: borderColor),
          size: Size.infinite,
        ),
      ],
    );
  }
}

class _CornerDecoratorPainter extends CustomPainter {
  final Color color;

  _CornerDecoratorPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final cornerSize = 15.0;
    final offset = 8.0;

    // Top left corner
    canvas.drawLine(
      Offset(offset, offset + cornerSize),
      Offset(offset, offset),
      paint,
    );
    canvas.drawLine(
      Offset(offset, offset),
      Offset(offset + cornerSize, offset),
      paint,
    );

    // Top right corner
    canvas.drawLine(
      Offset(size.width - offset, offset + cornerSize),
      Offset(size.width - offset, offset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - offset, offset),
      Offset(size.width - offset - cornerSize, offset),
      paint,
    );

    // Bottom left corner
    canvas.drawLine(
      Offset(offset, size.height - offset - cornerSize),
      Offset(offset, size.height - offset),
      paint,
    );
    canvas.drawLine(
      Offset(offset, size.height - offset),
      Offset(offset + cornerSize, size.height - offset),
      paint,
    );

    // Bottom right corner
    canvas.drawLine(
      Offset(size.width - offset, size.height - offset - cornerSize),
      Offset(size.width - offset, size.height - offset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - offset, size.height - offset),
      Offset(size.width - offset - cornerSize, size.height - offset),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerDecoratorPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
