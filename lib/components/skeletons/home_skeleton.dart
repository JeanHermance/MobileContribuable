import 'package:flutter/material.dart';

class HomeSkeleton extends StatefulWidget {
  const HomeSkeleton({super.key});

  @override
  State<HomeSkeleton> createState() => _HomeSkeletonState();
}

class _HomeSkeletonState extends State<HomeSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Section Skeleton
              _buildHeroSkeleton(),
              const SizedBox(height: 60),
              
              // Content Padding
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    // Statistics/Quick Actions Skeleton
                    _buildCardSkeleton(height: 180),
                    const SizedBox(height: 24),
                    
                    // Zones Section Skeleton
                    _buildZonesSkeleton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSkeleton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Background
        Container(
          height: 280,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // Header Row (Avatar + Name)
                Row(
                  children: [
                    _buildPulseContainer(width: 50, height: 50, borderRadius: 25),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPulseContainer(width: 120, height: 16),
                        const SizedBox(height: 8),
                        _buildPulseContainer(width: 80, height: 12),
                      ],
                    ),
                    const Spacer(),
                    _buildPulseContainer(width: 40, height: 40, borderRadius: 12),
                  ],
                ),
                const SizedBox(height: 30),
                // Welcome Text
                _buildPulseContainer(width: 200, height: 24),
                const SizedBox(height: 12),
                _buildPulseContainer(width: 150, height: 16),
                
                const SizedBox(height: 30),
                // Municipality Selector
                _buildPulseContainer(width: double.infinity, height: 50, borderRadius: 12),
              ],
            ),
          ),
        ),
        // Search Bar
        Positioned(
          bottom: -30,
          left: 16,
          right: 16,
          child: _buildPulseContainer(
            width: double.infinity, 
            height: 60, 
            borderRadius: 16,
            color: Colors.white,
            hasShadow: true,
          ),
        ),
      ],
    );
  }

  Widget _buildZonesSkeleton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              _buildPulseContainer(width: 40, height: 40, borderRadius: 12),
              const SizedBox(width: 16),
              _buildPulseContainer(width: 120, height: 20),
            ],
          ),
          const SizedBox(height: 20),
          // List Items
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) => _buildZoneItemSkeleton(),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneItemSkeleton() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildPulseContainer(width: 40, height: 40, borderRadius: 8),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPulseContainer(width: 100, height: 16),
                const SizedBox(height: 8),
                _buildPulseContainer(width: 140, height: 12),
              ],
            ),
          ),
          _buildPulseContainer(width: 24, height: 24, borderRadius: 12),
        ],
      ),
    );
  }

  Widget _buildCardSkeleton({required double height}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildPulseContainer(width: 40, height: 40, borderRadius: 12),
                const SizedBox(width: 16),
                _buildPulseContainer(width: 150, height: 20),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildPulseContainer(width: double.infinity, height: 80, borderRadius: 12)),
                const SizedBox(width: 16),
                Expanded(child: _buildPulseContainer(width: double.infinity, height: 80, borderRadius: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulseContainer({
    required double width,
    required double height,
    double borderRadius = 4,
    Color? color,
    bool hasShadow = false,
  }) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color ?? Colors.grey[300],
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: hasShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
      ),
    );
  }
}
