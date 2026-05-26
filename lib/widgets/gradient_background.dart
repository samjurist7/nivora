import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Animated Gradient Background Widget
/// Features:
/// - Smooth gradient animation
/// - Subtle parallax effect
/// - Theme-aware colors
/// - Performance optimized for 60fps
class GradientBackground extends StatefulWidget {
  final Widget child;
  final List<Color>? colors;
  final bool animated;
  final Duration duration;

  const GradientBackground({
    super.key,
    required this.child,
    this.colors,
    this.animated = true,
    this.duration = const Duration(seconds: 8),
  });

  @override
  State<GradientBackground> createState() => _GradientBackgroundState();
}

class _GradientBackgroundState extends State<GradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: widget.duration,
    vsync: this,
  );

  late final Animation<Alignment> _alignmentAnimation = AlignmentTween(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  ));

  @override
  void initState() {
    super.initState();
    if (widget.animated) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultColors = isDark
        ? [
            AppColors.darkBackground,
            AppColors.darkSurface.withOpacity(0.5),
            AppColors.primary.withOpacity(0.05),
          ]
        : [
            AppColors.lightBackground,
            AppColors.lightSurface.withOpacity(0.5),
            AppColors.primary.withOpacity(0.03),
          ];

    return AnimatedBuilder(
      animation: _alignmentAnimation,
      builder: (context, child) {
        final currentAlignment = _alignmentAnimation.value;
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.colors ?? defaultColors,
              begin: currentAlignment,
              end: Alignment(
                currentAlignment.x + 0.2,
                currentAlignment.y + 0.2,
              ),
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// Floating Particles Background Effect
/// Adds subtle animated particles for depth
class ParticleBackground extends StatefulWidget {
  final Widget child;
  final int particleCount;

  const ParticleBackground({
    super.key,
    required this.child,
    this.particleCount = 6,
  });

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with TickerProviderStateMixin {
  final List<AnimationController> _controllers = [];
  final List<Animation<Offset>> _offsetAnimations = [];

  @override
  void initState() {
    super.initState();
    _initParticles();
  }

  void _initParticles() {
    for (int i = 0; i < widget.particleCount; i++) {
      final controller = AnimationController(
        duration: Duration(seconds: 15 + (i * 3)),
        vsync: this,
      );
      _controllers.add(controller);

      final offsetAnimation = Tween<Offset>(
        begin: Offset(
          (i % 3 - 1) * 0.3,
          1.2,
        ),
        end: Offset(
          (i % 3 - 1) * 0.3,
          -0.2,
        ),
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOut,
      ));
      _offsetAnimations.add(offsetAnimation);
      controller.repeat(reverse: false);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Particles
        ...List.generate(widget.particleCount, (index) {
          return AnimatedBuilder(
            animation: _offsetAnimations[index],
            builder: (context, child) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: Transform.translate(
                    offset: _offsetAnimations[index].value *
                        MediaQuery.of(context).size.shortestSide,
                    child: Container(
                      width: 80 + (index * 20),
                      height: 80 + (index * 20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            (isDark
                                    ? AppColors.primary
                                    : AppColors.primary)
                                .withOpacity(0.03 - (index * 0.004)),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),
        // Child content
        widget.child,
      ],
    );
  }
}
