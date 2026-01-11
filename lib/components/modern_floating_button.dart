import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ModernFloatingButton extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isExtended;
  final bool showPulseAnimation;
  final double? elevation;

  const ModernFloatingButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
    this.isExtended = true,
    this.showPulseAnimation = false,
    this.elevation,
  });

  @override
  State<ModernFloatingButton> createState() => _ModernFloatingButtonState();
}

class _ModernFloatingButtonState extends State<ModernFloatingButton>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    if (widget.showPulseAnimation) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _scaleController.reverse();
  }

  void _handleTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = widget.backgroundColor ?? theme.colorScheme.primary;
    final foregroundColor = widget.foregroundColor ?? Colors.white;

    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _pulseAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value * (widget.showPulseAnimation ? _pulseAnimation.value : 1.0),
          child: GestureDetector(
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.isExtended ? 28 : 28),
                boxShadow: [
                  BoxShadow(
                    color: backgroundColor.withValues(alpha: 0.3),
                    blurRadius: widget.elevation ?? 12,
                    offset: const Offset(0, 6),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: widget.isExtended
                  ? FloatingActionButton.extended(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        widget.onPressed();
                      },
                      icon: Icon(
                        widget.icon,
                        size: 24,
                      ),
                      backgroundColor: backgroundColor,
                      foregroundColor: foregroundColor,
                      elevation: 0,
                      highlightElevation: 0,
                      label: Text(
                        widget.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          letterSpacing: 0.5,
                          color: foregroundColor,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    )
                  : FloatingActionButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        widget.onPressed();
                      },
                      backgroundColor: backgroundColor,
                      foregroundColor: foregroundColor,
                      elevation: 0,
                      highlightElevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Icon(
                        widget.icon,
                        size: 28,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// Widget pour créer un bouton flottant avec effet de gradient
class GradientFloatingButton extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final List<Color> gradientColors;
  final bool isExtended;
  final bool showGlow;

  const GradientFloatingButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.gradientColors,
    this.isExtended = true,
    this.showGlow = true,
  });

  @override
  State<GradientFloatingButton> createState() => _GradientFloatingButtonState();
}

class _GradientFloatingButtonState extends State<GradientFloatingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) => _controller.forward(),
            onTapUp: (_) => _controller.reverse(),
            onTapCancel: () => _controller.reverse(),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(widget.isExtended ? 28 : 28),
                boxShadow: widget.showGlow ? [
                  BoxShadow(
                    color: widget.gradientColors.first.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: 2,
                  ),
                ] : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    widget.onPressed();
                  },
                  borderRadius: BorderRadius.circular(widget.isExtended ? 28 : 28),
                  child: Container(
                    padding: widget.isExtended 
                        ? const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
                        : const EdgeInsets.all(16),
                    child: widget.isExtended
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.icon,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                widget.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          )
                        : Icon(
                            widget.icon,
                            color: Colors.white,
                            size: 28,
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
