import 'package:flutter/material.dart';

class AnimatedBadgeButton extends StatefulWidget {
  final IconData icon;
  final int badgeCount;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color iconColor;
  final Duration animationDuration;
  final Duration badgeAnimationDuration;
  final BorderRadius borderRadius;

  const AnimatedBadgeButton({
    super.key,
    required this.icon,
    this.badgeCount = 0,
    this.onPressed,
    this.backgroundColor = Colors.blue,
    this.iconColor = Colors.white,
    this.animationDuration = const Duration(milliseconds: 150),
    this.badgeAnimationDuration = const Duration(milliseconds: 200),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  State<AnimatedBadgeButton> createState() => _AnimatedBadgeButtonState();
}

class _AnimatedBadgeButtonState extends State<AnimatedBadgeButton>
    with TickerProviderStateMixin {
  late AnimationController _buttonController;
  late AnimationController _badgeController;
  late Animation<double> _buttonScale;
  late Animation<double> _badgeScale;

  @override
  void initState() {
    super.initState();
    
    _buttonController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _badgeController = AnimationController(
      duration: widget.badgeAnimationDuration,
      vsync: this,
    );

    _buttonScale = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeInOut,
    ));

    _badgeScale = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _badgeController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void didUpdateWidget(AnimatedBadgeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.badgeCount > oldWidget.badgeCount && mounted) {
      _badgeController.forward().then((_) {
        if (mounted) {
          _badgeController.reverse();
        }
      });
    }
  }

  @override
  void dispose() {
    _buttonController.dispose();
    _badgeController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (mounted) {
      _buttonController.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (mounted) {
      _buttonController.reverse();
    }
  }

  void _onTapCancel() {
    if (mounted) {
      _buttonController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _buttonScale,
        builder: (context, child) {
          return Transform.scale(
            scale: _buttonScale.value,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: widget.borderRadius,
                boxShadow: [
                  BoxShadow(
                    color: widget.backgroundColor.withAlpha((0.3 * 255).round()),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      widget.icon,
                      color: widget.iconColor,
                      size: 24,
                    ),
                  ),
                  if (widget.badgeCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: AnimatedBuilder(
                        animation: _badgeScale,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _badgeScale.value,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                widget.badgeCount > 99 ? '99+' : '${widget.badgeCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
