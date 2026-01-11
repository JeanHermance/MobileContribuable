import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double? size;
  final IconData? icon;
  final String? title;
  final String? subtitle;
  final Color? titleColor;
  final Color? subtitleColor;
  final Gradient? titleGradient;

  const AppLogo({
    super.key,
    this.size,
    this.icon,
    this.title,
    this.subtitle,
    this.titleColor,
    this.subtitleColor,
    this.titleGradient,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    final isShortScreen = screenHeight < 600;
    
    final logoSize = size ?? (isShortScreen ? 60 : isSmallScreen ? 70 : 80);
    
    return Column(
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Image.asset(
            'assets/images/logo/application/TSENA SERVICE LOGO - by Tsantaniaina Design.png',
            width: logoSize,
            height: logoSize,
            fit: BoxFit.contain,
          ),
        ),
        if (title != null) ...[
          SizedBox(height: isShortScreen ? 16 : 24),
          if (titleGradient != null)
            ShaderMask(
              shaderCallback: (bounds) => titleGradient!.createShader(
                Rect.fromLTWH(0, 0, bounds.width, bounds.height),
              ),
              child: Text(
                title ?? '',
                style: TextStyle(
                  fontSize: isSmallScreen ? 20 : isShortScreen ? 22 : 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // Required for ShaderMask
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            Text(
              title ?? '',
              style: TextStyle(
                fontSize: isShortScreen ? 24 : isSmallScreen ? 28 : 32,
                fontWeight: FontWeight.bold,
                color: titleColor ?? Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
        ],
        if (subtitle != null) ...[
          SizedBox(height: isShortScreen ? 20 : 24),
          Text(
            subtitle ?? '',
            style: TextStyle(
              fontSize: isSmallScreen ? 20 : 24, // Same size as title
              fontWeight: FontWeight.bold, // Bold
              color: Colors.black, // Black
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
