import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Animated Card Widget with Material Design 3 styling
/// Features:
/// - Smooth scale animation on tap
/// - Hover effect (for web/desktop)
/// - Gradient border option
/// - Shadow elevation
/// - Accessibility support
class AnimatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool gradientBorder;
  final List<Color>? gradientColors;
  final IconData? icon;
  final Color? iconColor;
  final bool enabled;

  const AnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.gradientBorder = false,
    this.gradientColors,
    this.icon,
    this.iconColor,
    this.enabled = true,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;

  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 150),
    vsync: this,
  );

  late final Animation<double> _scaleAnimation = Tween<double>(
    begin: 1.0,
    end: 0.97,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  ));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHoverEnter() {
    if (widget.enabled) {
      setState(() => _isHovered = true);
    }
  }

  void _onHoverExit() {
    setState(() => _isHovered = false);
  }

  void _onTapDown() {
    if (widget.enabled) {
      setState(() => _isPressed = true);
      _controller.forward();
    }
  }

  void _onTapUp() {
    if (widget.enabled) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.enabled) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        onEnter: (_) => _onHoverEnter(),
        onExit: (_) => _onHoverExit(),
        cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          onTapDown: (_) => _onTapDown(),
          onTapUp: (_) => _onTapUp(),
          onTapCancel: _onTapCancel,
          onTap: widget.enabled ? widget.onTap : null,
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: widget.gradientBorder && widget.gradientColors != null
                        ? LinearGradient(
                            colors: widget.gradientColors!,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: widget.gradientBorder
                        ? AppColors.darkSurface
                        : isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                    border: widget.gradientBorder
                        ? null
                        : Border.all(
                            color: isDark
                                ? _isHovered
                                    ? AppColors.darkOutline
                                    : AppColors.darkOutlineVariant
                                : _isHovered
                                    ? AppColors.primary.withOpacity(0.3)
                                    : AppColors.lightOutline,
                            width: _isHovered ? 2 : 1,
                          ),
                    boxShadow: [
                      if (_isHovered || _isPressed)
                        BoxShadow(
                          color: isDark
                              ? AppColors.shadowDark
                              : AppColors.shadowLight.withOpacity(0.15),
                          blurRadius: _isHovered ? 20 : 12,
                          offset: Offset(0, _isHovered ? 8 : 4),
                          spreadRadius: _isHovered ? 2 : 0,
                        ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(widget.gradientBorder ? 19 : 20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      color: widget.gradientBorder
                          ? AppColors.darkSurface
                          : null,
                      child: widget.child,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Connection Type Card with Icon
class ConnectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final bool gradientBorder;
  final bool darkBackground;

  const ConnectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.gradientBorder = false,
    this.darkBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedCard(
      onTap: onTap,
      semanticLabel: '$title: $subtitle',
      gradientBorder: gradientBorder,
      gradientColors: gradientBorder
          ? [iconColor.withOpacity(0.3), iconColor.withOpacity(0.15)]
          : null,
      child: Row(
        children: [
          // Icon Container
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: darkBackground
                    ? [iconColor.withOpacity(0.25), iconColor.withOpacity(0.1)]
                    : [iconColor.withOpacity(0.15), iconColor.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),

          // Text Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkOnBackground,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.darkOnSurface,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Chevron Icon
          Icon(
            Icons.chevron_right_rounded,
            size: 28,
            color: isDark
                ? AppColors.darkOnSurfaceVariant
                : AppColors.lightOnSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
