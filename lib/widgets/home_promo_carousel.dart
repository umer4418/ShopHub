import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/product_controller.dart';
import '../theme/colors.dart';

class PromoCampaign {
  final String tag;
  final String badge;
  final String headline;
  final String subtitle;
  final String cta;
  final String categoryId;
  final List<Color> gradient;
  final IconData icon;
  final String? discountPill;

  const PromoCampaign({
    required this.tag,
    required this.badge,
    required this.headline,
    required this.subtitle,
    required this.cta,
    required this.categoryId,
    required this.gradient,
    required this.icon,
    this.discountPill,
  });
}

class HomePromoCarousel extends StatefulWidget {
  const HomePromoCarousel({super.key});

  static const List<PromoCampaign> campaigns = [
    PromoCampaign(
      tag: '🔥 MEGA SALE',
      badge: 'UP TO 70% OFF',
      headline: 'Electronics & Gadgets',
      subtitle: 'Audio, smartwatches & accessories at special prices.',
      cta: 'Shop Electronics →',
      categoryId: 'electronics',
      gradient: [Color(0xFFE65100), Color(0xFFF85606), Color(0xFFFF7043)],
      icon: Icons.devices_other,
      discountPill: '-70%',
    ),
    PromoCampaign(
      tag: '✨ FASHION WEEK',
      badge: 'NEW ARRIVALS',
      headline: 'Fresh Styles. Every Day.',
      subtitle: 'Discover trending apparel, footwear & modern styles.',
      cta: 'Explore Fashion →',
      categoryId: 'fashion',
      gradient: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
      icon: Icons.checkroom,
      discountPill: 'NEW',
    ),
    PromoCampaign(
      tag: '🏡 HOME & LIVING',
      badge: 'EXCLUSIVE DEALS',
      headline: 'Refresh Your Space',
      subtitle: 'Smart kitchen, home essentials & lifestyle discounts.',
      cta: 'Shop Home →',
      categoryId: 'home',
      gradient: [Color(0xFF064E3B), Color(0xFF059669), Color(0xFF10B981)],
      icon: Icons.chair_outlined,
      discountPill: 'DEALS',
    ),
    PromoCampaign(
      tag: '🌸 BEAUTY & CARE',
      badge: 'TRENDING NOW',
      headline: 'Glow Every Day',
      subtitle: 'Premium skincare, fragrances & self-care essentials.',
      cta: 'Shop Beauty →',
      categoryId: 'beauty',
      gradient: [Color(0xFF831843), Color(0xFFBE185D), Color(0xFFF43F5E)],
      icon: Icons.spa_outlined,
      discountPill: 'POPULAR',
    ),
  ];

  @override
  State<HomePromoCarousel> createState() => _HomePromoCarouselState();
}

class _HomePromoCarouselState extends State<HomePromoCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoScrollTimer;
  bool _isUserInteracting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients || _isUserInteracting) return;
      final next = (_currentPage + 1) % HomePromoCarousel.campaigns.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onUserTouchStart() {
    _isUserInteracting = true;
  }

  void _onUserTouchEnd() {
    _isUserInteracting = false;
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToCategory(String categoryId) {
    if (Get.isRegistered<ProductController>()) {
      Get.find<ProductController>().setFilters(categoryId: categoryId);
    }
    Navigator.pushNamed(context, AppRoutes.products);
  }

  @override
  Widget build(BuildContext context) {
    final campaigns = HomePromoCarousel.campaigns;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardHeight = screenWidth >= 600 ? 144.0 : 140.0;

    return Column(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification) {
              _onUserTouchStart();
            } else if (notification is ScrollEndNotification) {
              _onUserTouchEnd();
            }
            return false;
          },
          child: SizedBox(
            height: cardHeight,
            child: PageView.builder(
              controller: _pageController,
              itemCount: campaigns.length,
              onPageChanged: (idx) => setState(() => _currentPage = idx),
              itemBuilder: (context, i) {
                final c = campaigns[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  child: InkWell(
                    onTap: () => _navigateToCategory(c.categoryId),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: c.gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: c.gradient.first.withValues(alpha: 0.28),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            // Decorative Background Shapes
                            Positioned(
                              right: -25,
                              bottom: -35,
                              child: Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 50,
                              top: -40,
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                            ),

                            // Main Card Content
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
                              child: Row(
                                children: [
                                  // Left Text Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Badge / Tag Pill
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.25),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Text(
                                            c.tag,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),

                                        // Discount Headline
                                        Text(
                                          c.badge,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.2,
                                            height: 1.1,
                                          ),
                                        ),
                                        const SizedBox(height: 2),

                                        // Supporting Text
                                        Text(
                                          c.subtitle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.92),
                                            fontSize: 11,
                                            height: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        // CTA Button
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 5.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(20),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.15),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                c.cta,
                                                style: TextStyle(
                                                  color: c.gradient.first,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  // Right Decorative Composition
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 72,
                                        height: 72,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withValues(alpha: 0.18),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.35),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.08),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Icon(
                                            c.icon,
                                            size: 36,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      if (c.discountPill != null) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.22),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            c.discountPill!,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 7),

        // Carousel Page Indicator Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(campaigns.length, (i) {
            final isCurrent = i == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isCurrent ? 22 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isCurrent ? ShopColors.primary : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}
