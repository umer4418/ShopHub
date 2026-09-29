import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/cart_controller.dart';
import '../controllers/product_controller.dart';
import '../controllers/wishlist_controller.dart';
import '../models/product.dart';
import '../theme/colors.dart';
import '../utils/money.dart';
import '../widgets/app_footer.dart';
import '../widgets/home_promo_carousel.dart';
import '../widgets/product_card.dart';
import '../widgets/shop_product_image.dart';
import '../widgets/shop_search_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.onSeeCategories,
    this.onSeeAccount,
  });

  final VoidCallback? onSeeCategories;
  final VoidCallback? onSeeAccount;

  @override
  Widget build(BuildContext context) {
    final productCtrl = Get.find<ProductController>();
    final cartCtrl = Get.find<CartController>();
    final wishlistCtrl = Get.find<WishlistController>();

    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= 1200
        ? 5
        : width >= 900
            ? 4
            : width >= 600
                ? 3
                : 2;
    final cardAspectRatio = width >= 600 ? 0.72 : 0.65;

    return Obx(() {
      final flashDeals = productCtrl.products
          .where((p) => p.discountPercent > 0)
          .take(6)
          .toList();

      return RefreshIndicator(
        onRefresh: () async {
          productCtrl.init();
        },
        color: ShopColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Modern Header with Logo, Navigation Icons, and Search Bar
            SliverAppBar(
              pinned: true,
              backgroundColor: ShopColors.primary,
              titleSpacing: 12,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ShopHub',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                      fontSize: 19,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Wishlist',
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.wishlist),
                  icon: Badge(
                    isLabelVisible: wishlistCtrl.count > 0,
                    label: Text('${wishlistCtrl.count}'),
                    child: const Icon(
                      Icons.favorite_border_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'ShopBot AI Support',
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.chatbot),
                  icon: const Icon(
                    Icons.smart_toy_outlined,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  tooltip: 'Cart',
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.cart),
                  icon: Badge(
                    isLabelVisible: cartCtrl.cartCount > 0,
                    label: Text('${cartCtrl.cartCount}'),
                    child: const Icon(
                      Icons.shopping_cart_outlined,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'My Account',
                  onPressed: () {
                    if (onSeeAccount != null) {
                      onSeeAccount!();
                    } else {
                      Navigator.pushNamed(context, AppRoutes.login);
                    }
                  },
                  icon: const Icon(
                    Icons.person_outline_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(58),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: ShopSearchBar(),
                ),
              ),
            ),

            // Top Promotional Carousel with Multi-Campaign Banners
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 4),
                child: HomePromoCarousel(),
              ),
            ),

            // Trust Badges / Value Proposition Strip
            const SliverToBoxAdapter(child: _ServiceHighlightsStrip()),

            // Category Strip Header & Horizontal List
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Shop by Category',
                subtitle: 'Explore all marketplace departments',
                action: 'See all',
                onTap: onSeeCategories,
              ),
            ),
            SliverToBoxAdapter(
              child: _CategoryStrip(onSeeCategories: onSeeCategories),
            ),

            // Featured Products Section Header
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Featured Products',
                subtitle: 'Handpicked top-rated products for you',
                action: 'View all',
                onTap: () {
                  productCtrl.resetFilters();
                  Navigator.pushNamed(context, AppRoutes.products);
                },
              ),
            ),

            // Featured Products Grid
            if (productCtrl.featured.isEmpty)
              const SliverToBoxAdapter(
                child: _EmptySection(message: 'No featured products found.'),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: cardAspectRatio,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final p = productCtrl.featured[i];
                      return ProductCard(
                        product: p,
                        wished: wishlistCtrl.inWishlist(p.id),
                        onWish: () => wishlistCtrl.toggleWishlist(p.id),
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.productDetail,
                          arguments: p.id,
                        ),
                      );
                    },
                    childCount: productCtrl.featured.length,
                  ),
                ),
              ),

            // Flash Deals / Special Offers (Only if discounted products exist)
            if (flashDeals.isNotEmpty)
              SliverToBoxAdapter(
                child: _FlashDealsSection(deals: flashDeals),
              ),


            // Mid-Page Delivery / Trust Promotion Banner
            const SliverToBoxAdapter(child: _MidPagePerksBanner()),

            // Popular Products Section Header
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Popular Products',
                subtitle: 'Trending items in Pakistan right now',
                action: 'View all',
                onTap: () {
                  productCtrl.setFilters(sort: 'popular');
                  Navigator.pushNamed(context, AppRoutes.products);
                },
              ),
            ),

            // Popular Products Grid
            if (productCtrl.popular.isEmpty)
              const SliverToBoxAdapter(
                child: _EmptySection(message: 'No popular products found.'),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: cardAspectRatio,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final p = productCtrl.popular[i];
                      return ProductCard(
                        product: p,
                        wished: wishlistCtrl.inWishlist(p.id),
                        onWish: () => wishlistCtrl.toggleWishlist(p.id),
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.productDetail,
                          arguments: p.id,
                        ),
                      );
                    },
                    childCount: productCtrl.popular.length,
                  ),
                ),
              ),

            // Modern App Footer
            const SliverToBoxAdapter(child: AppFooter()),
          ],
        ),
      );
    });
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.subtitle,
    required this.action,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 10, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: ShopColors.text,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: ShopColors.muted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  action,
                  style: const TextStyle(
                    color: ShopColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 11,
                  color: ShopColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceHighlightsStrip extends StatelessWidget {
  const _ServiceHighlightsStrip();

  @override
  Widget build(BuildContext context) {
    const highlights = [
      (
        icon: Icons.local_shipping_outlined,
        title: 'Free Delivery',
        desc: 'Over Rs. 2,000',
      ),
      (
        icon: Icons.verified_outlined,
        title: '100% Genuine',
        desc: 'Direct brands',
      ),
      (
        icon: Icons.cached_outlined,
        title: 'Easy Returns',
        desc: '7-day policy',
      ),
      (
        icon: Icons.smart_toy_outlined,
        title: '24/7 AI Support',
        desc: 'Instant answers',
      ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 2),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: highlights.map((h) {
            return InkWell(
              onTap: h.title.contains('AI')
                  ? () => Navigator.pushNamed(context, AppRoutes.chatbot)
                  : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6.5),
                      decoration: BoxDecoration(
                        color: ShopColors.primarySoft.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(h.icon, size: 17, color: ShopColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          h.title,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: ShopColors.text,
                          ),
                        ),
                        Text(
                          h.desc,
                          style: const TextStyle(
                            fontSize: 10,
                            color: ShopColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({this.onSeeCategories});

  final VoidCallback? onSeeCategories;

  IconData _icon(String name) {
    return switch (name) {
      'devices' => Icons.devices_other,
      'checkroom' => Icons.checkroom,
      'chair' => Icons.chair_outlined,
      'spa' => Icons.spa_outlined,
      'sports_soccer' => Icons.sports_soccer,
      'shopping_basket' => Icons.shopping_basket_outlined,
      'child_care' => Icons.child_care,
      'smartphone' => Icons.smartphone,
      _ => Icons.category_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final productCtrl = Get.find<ProductController>();
    return Obx(
      () => SizedBox(
        height: 84,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          scrollDirection: Axis.horizontal,
          itemCount: productCtrl.categories.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) {
            final c = productCtrl.categories[i];
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                productCtrl.setFilters(categoryId: c.id);
                Navigator.pushNamed(context, AppRoutes.products);
              },
              child: SizedBox(
                width: 72,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            ShopColors.primarySoft.withValues(alpha: 0.7),
                            ShopColors.primarySoft.withValues(alpha: 0.3),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ShopColors.primary.withValues(alpha: 0.18),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          _icon(c.icon),
                          color: ShopColors.primary,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ShopColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FlashDealsSection extends StatelessWidget {
  const _FlashDealsSection({required this.deals});

  final List<Product> deals;

  @override
  Widget build(BuildContext context) {
    if (deals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 10, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Flash Deals',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: ShopColors.text,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 12, color: Colors.red),
                    SizedBox(width: 4),
                    Text(
                      'Ends in 08:45:20',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  final pCtrl = Get.find<ProductController>();
                  pCtrl.setFilters(sort: 'discount');
                  Navigator.pushNamed(context, AppRoutes.products);
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View all',
                      style: TextStyle(
                        color: ShopColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: ShopColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 226,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            scrollDirection: Axis.horizontal,
            itemCount: deals.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final p = deals[i];
              return InkWell(
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.productDetail,
                  arguments: p.id,
                ),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 156,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(13),
                            ),
                            child: SizedBox(
                              height: 110,
                              width: double.infinity,
                              child: ShopProductImage(
                                imageUrl: p.imageUrl,
                                categoryId: p.categoryId,
                                productName: p.name,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '-${p.discountPercent}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: ShopColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pkr.format(p.price),
                              style: const TextStyle(
                                color: ShopColors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                            Text(
                              pkr.format(p.originalPrice),
                              style: const TextStyle(
                                color: ShopColors.muted,
                                fontSize: 10.5,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: 0.78,
                                minHeight: 4,
                                backgroundColor: Colors.orange.shade50,
                                valueColor: const AlwaysStoppedAnimation(
                                  ShopColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Almost Sold Out',
                              style: TextStyle(
                                color: ShopColors.muted,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MidPagePerksBanner extends StatelessWidget {
  const _MidPagePerksBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 20, 14, 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E1B4B).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Free Nationwide Delivery',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'On all orders over Rs. 2,000. Delivered to your doorstep in 2-4 days.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11.5,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Text(
        message,
        style: const TextStyle(
          color: ShopColors.muted,
          fontSize: 14,
        ),
      ),
    );
  }
}