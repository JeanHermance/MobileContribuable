import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final bool enableSafeArea;

  const ResponsiveLayout({
    super.key,
    required this.child,
    this.padding,
    this.enableSafeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    final isShortScreen = screenHeight < 600;
    
    // Calcul du padding adaptatif
    final adaptivePadding = padding ?? EdgeInsets.symmetric(
      horizontal: isSmallScreen ? 16 : 24,
      vertical: isShortScreen ? 8 : 16,
    );

    Widget content = Padding(
      padding: adaptivePadding,
      child: child,
    );

    if (enableSafeArea) {
      content = SafeArea(child: content);
    }

    return content;
  }
}

class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? (screenWidth > 600 ? 400 : double.infinity),
      ),
      padding: padding ?? EdgeInsets.all(isSmallScreen ? 12 : 16),
      margin: margin,
      child: child,
    );
  }
}

class ResponsiveSizedBox extends StatelessWidget {
  final double? height;
  final double? width;

  const ResponsiveSizedBox({
    super.key,
    this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isShortScreen = screenHeight < 600;
    final isSmallScreen = screenWidth < 360;
    
    return SizedBox(
      height: height != null 
          ? (isShortScreen ? (height ?? 0) * 0.7 : (height ?? 0))
          : null,
      width: width != null 
          ? (isSmallScreen ? (width ?? 0) * 0.9 : (width ?? 0))
          : null,
    );
  }
}
