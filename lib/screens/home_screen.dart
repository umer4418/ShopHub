import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/cart_controller.dart';
import '../controllers/product_controller.dart';
import '../controllers/wishlist_controller.dart';
import '../theme/colors.dart';
import '../widgets/app_footer.dart';
import '../widgets/product_card.dart';
import '../widgets/shop_search_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.onSeeCategories});

  final VoidCallback? onSeeCategories;

  @override
  Widget build(BuildContext context) {
    final productCtrl = Get.find<ProductController>();
    final cartCtrl = Get.find<CartController>();
    final wishlistCtrl = Get.find<WishlistController>();

    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= 900 ? 4 : 2;

    return Obx(
      () => CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
          backgroundColor: ShopColors.primary,
          titleSpacing: 12,
          title: const Row(
            children: [
              Icon(Icons.storefront, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'ShopHub',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.2),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Wishlist',
              onPressed: () => Navigator.pushNamed(context, AppRoutes.wishlist),
              icon: Badge(
                isLabelVisible: wishlistCtrl.count > 0,
                label: Text('${wishlistCtrl.count}'),
                child: const Icon(Icons.favorite_border, color: Colors.white),
              ),
            ),
            IconButton(
              tooltip: 'ShopBot AI Support',
              onPressed: () => Navigator.pushNamed(context, AppRoutes.chatbot),
              icon: const Icon(Icons.smart_toy_outlined, color: Colors.white),
            ),
            IconButton(
              tooltip: 'Cart',
              onPressed: () => Navigator.pushNamed(context, AppRoutes.cart),
              icon: Badge(
                isLabelVisible: cartCtrl.cartCount > 0,
                label: Text('${cartCtrl.cartCount}'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(64),
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: ShopSearchBar(),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                child: PageView(
                  controller: PageController(viewportFraction: 0.92),
                  children: const [
                    _BannerCard(
                      title: 'Mega Sale',
                      subtitle: 'Up to 70% off electronics',
                      color: ShopColors.primary,
                    ),
                    _BannerCard(
                      title: 'Fashion Week',
                      subtitle: 'Fresh drops every day',
                      color: ShopColors.navy,
                    ),
                    _BannerCard(
                      title: 'Home Refresh',
                      subtitle: 'Kitchen & living deals',
                      color: Color(0xFF0EA5E9),
                    ),
                  ],
                ),
              ),
              _SectionHeader(
                title: 'Categories',
                action: 'See all',
                onTap: onSeeCategories,
              ),
            ],
          ),
        ),
        const SliverToBoxAdapter(child: _CategoryStrip()),
        SliverToBoxAdapter(
          child: _SectionHeader(
            title: 'Featured products',
            action: 'View all',
            onTap: () {
              productCtrl.resetFilters();
              Navigator.pushNamed(context, AppRoutes.products);
            },
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.62,
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
        SliverToBoxAdapter(
          child: _SectionHeader(
            title: 'Popular products',
            action: 'View all',
            onTap: () {
              productCtrl.setFilters(sort: 'popular');
              Navigator.pushNamed(context, AppRoutes.products);
            },
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.62,
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
        const SliverToBoxAdapter(child: AppFooter()),
      ],
    ),);
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.title, required this.subtitle, required this.color});

  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.75)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.action, this.onTap});

  final String title;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 10),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const Spacer(),
          TextButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip();

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
        height: 108,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          scrollDirection: Axis.horizontal,
          itemCount: productCtrl.categories.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final c = productCtrl.categories[i];
            return InkWell(
              onTap: () {
                productCtrl.setFilters(categoryId: c.id);
                Navigator.pushNamed(context, AppRoutes.products);
              },
              child: SizedBox(
                width: 78,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: ShopColors.primarySoft,
                      child: Icon(_icon(c.icon), color: ShopColors.primary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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