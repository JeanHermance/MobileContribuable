import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tsena_servisy/components/styled_title.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final bool showBackButton;
  final Widget? trailing;
  final List<Color>? gradientColors;
  final bool enableGlassEffect;
  final VoidCallback? onBackPressed;

  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showBackButton = false,
    this.trailing,
    this.gradientColors,
    this.enableGlassEffect = false,
    this.onBackPressed,
  });

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (subtitle != null ? 70 : 40),
      );
}

class _CustomAppBarState extends State<CustomAppBar> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: -50.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Removed SystemChrome configuration to let each screen handle status bar styling

    final defaultGradient = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
      Theme.of(context).colorScheme.primaryContainer,
    ];
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.only(top: 25, bottom: 20, left: 20, right: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.gradientColors ?? defaultGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: widget.enableGlassEffect ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ] : null,
          ),
          child: SafeArea(
            bottom: false,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (widget.showBackButton)
                          Container(
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const FaIcon(
                                FontAwesomeIcons.angleLeft,
                                size: 20.0,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                if (widget.onBackPressed != null) {
                                  widget.onBackPressed!();
                                } else {
                                  Navigator.pop(context);
                                }
                              },
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              StyledTitle(
                                title: widget.title,
                                textAlign: TextAlign.left,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    blurRadius: 4.0,
                                    color: Colors.black.withValues(alpha: 0.3),
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              if (widget.subtitle != null) ...[
                                const SizedBox(height: 4),
                                StyledTitle(
                                  title: widget.subtitle!,
                                  textAlign: TextAlign.left,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  shadows: [
                                    Shadow(
                                      blurRadius: 2.0,
                                      color: Colors.black.withValues(alpha: 0.2),
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (widget.trailing != null) 
                          Container(
                            margin: const EdgeInsets.only(left: 12),
                            child: widget.trailing!,
                          ),
                      ],
                    ),
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