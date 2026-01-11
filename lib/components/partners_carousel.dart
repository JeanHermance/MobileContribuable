import 'package:flutter/material.dart';
import 'dart:async';

class PartnersCarousel extends StatefulWidget {
  final double height;
  final Duration autoPlayDuration;
  
  const PartnersCarousel({
    super.key,
    this.height = 60,
    this.autoPlayDuration = const Duration(seconds: 3),
  });

  @override
  State<PartnersCarousel> createState() => _PartnersCarouselState();
}

class _PartnersCarouselState extends State<PartnersCarousel> {
  late PageController _pageController;
  late Timer _timer;
  int _currentPage = 0;
  
  // Liste des logos de partenaires
  final List<String> _partnerLogos = [
    'assets/images/logo/partenaires/AGM.jpg',
    'assets/images/logo/partenaires/UF.jpg',
    'assets/images/logo/partenaires/pnud.png',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoPlay();
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _timer = Timer.periodic(widget.autoPlayDuration, (timer) {
      if (_currentPage < _partnerLogos.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          // Titre "Nos partenaires"
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Nos partenaires',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          
          // Carrousel des logos
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: _partnerLogos.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: Image.asset(
                      _partnerLogos[index],
                      height: widget.height - 30, // Laisser de l'espace pour le titre
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: widget.height - 30,
                          width: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.image_not_supported,
                            color: Colors.grey[400],
                            size: 24,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Indicateurs de page
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _partnerLogos.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _currentPage == index ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: _currentPage == index
                      ? Colors.grey[600] // Dark grey for active
                      : Colors.grey[300],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
