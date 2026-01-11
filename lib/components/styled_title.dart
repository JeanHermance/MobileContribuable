import 'package:flutter/material.dart';

class StyledTitle extends StatelessWidget {
  final String title;
  final Color? color;
  final double? fontSize;
  final FontWeight? fontWeight;
  final double? letterSpacing;
  final List<Shadow>? shadows;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const StyledTitle({
    super.key,
    required this.title,
    this.color = Colors.white,
    this.fontSize = 32,
    this.fontWeight = FontWeight.w800,
    this.letterSpacing = -0.5,
    this.shadows,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final defaultShadows = [
      Shadow(
        color: Colors.black.withAlpha((0.2 * 255).round()),
        offset: const Offset(0, 2),
        blurRadius: 4,
      ),
    ];

    return Text(
      title,
      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
        color: color,
        fontWeight: fontWeight,
        fontSize: fontSize,
        letterSpacing: letterSpacing,
        shadows: shadows ?? defaultShadows,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}