import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/product_controller.dart';
import '../controllers/wishlist_controller.dart';
import '../models/product.dart';
import '../theme/colors.dart';
import '../widgets/product_card.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  static const route = AppRoutes.products;

  @override
  Widget build(BuildContext context) {
    final productCtrl = Get.find<ProductController>();
    final wishlistCtrl = Get.find<WishlistController>();

    return Obx(() {
      final items = productCtrl.filteredProducts;
      final cat = productCtrl.filterCategoryId == null
          ? null
          : productCtrl.categoryById(productCtrl.filterCategoryId!);

      return Scaffold(
        appBar: AppBar(
          title: Text(cat?.name ??
              (productCtrl.searchQuery.isEmpty ? 'All Products' : productCtrl.searchQuery)),
          actions: [
            IconButton(
              tooltip: 'Wishlist',
              onPressed: () => Navigator.pushNamed(context, AppRoutes.wishlist),
              icon: Badge(
                isLabelVisible: wishlistCtrl.count > 0,
                label: Text('${wishlistCtrl.count}'),
                child: const Icon(Icons.favorite_border),
              ),
            ),
            IconButton(
              tooltip: 'Filters',
              onPressed: () => _openFilters(context, productCtrl),
              icon: const Icon(Icons.tune),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Text('${items.length} items',
                      style: const TextStyle(color: ShopColors.muted)),
                  const Spacer(),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: productCtrl.sortBy,
                      items: const [
                        DropdownMenuItem(value: 'popular', child: Text('Popular')),
                        DropdownMenuItem(value: 'price_low', child: Text('Price: Low')),
                        DropdownMenuItem(value: 'price_high', child: Text('Price: High')),
                        DropdownMenuItem(value: 'rating', child: Text('Top rated')),
                        DropdownMenuItem(value: 'discount', child: Text('Best discount')),
                      ],
                      onChanged: (v) {
                        if (v != null) productCtrl.setFilters(sort: v);
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('No products match your filters.'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.62,
                      ),
                      itemCount: items.length,
                      itemBuilder: (_, i) =>
                          _card(context, productCtrl, wishlistCtrl, items[i]),
                    ),
            ),
          ],
        ),
      );
    });
  }

  Widget _card(
    BuildContext context,
    ProductController productCtrl,
    WishlistController wishlistCtrl,
    Product p,
  ) {
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
  }

  void _openFilters(BuildContext context, ProductController productCtrl) {
    var min = productCtrl.minPrice;
    var max = productCtrl.maxPrice;
    var rating = productCtrl.minRating;
    String? cat = productCtrl.filterCategoryId;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 8, 20, 20 + MediaQuery.paddingOf(ctx).bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filters',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  const Text('Category'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: cat == null,
                        onSelected: (_) => setModal(() => cat = null),
                      ),
                      ...productCtrl.categories.map(
                        (c) => ChoiceChip(
                          label: Text(c.name),
                          selected: cat == c.id,
                          onSelected: (_) => setModal(() => cat = c.id),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Price: ${min.round()} – ${max.round()}'),
                  RangeSlider(
                    min: 0,
                    max: 200000,
                    values: RangeValues(min, max),
                    labels: RangeLabels('${min.round()}', '${max.round()}'),
                    onChanged: (v) => setModal(() {
                      min = v.start;
                      max = v.end;
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text('Min rating: ${rating.toStringAsFixed(1)}+'),
                  Slider(
                    min: 0,
                    max: 5,
                    divisions: 10,
                    value: rating,
                    onChanged: (v) => setModal(() => rating = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          productCtrl.resetFilters();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Reset'),
                      ),
                      const Spacer(),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: ShopColors.primary),
                        onPressed: () {
                          productCtrl.setFilters(
                            categoryId: cat,
                            clearCategory: cat == null,
                            min: min,
                            max: max,
                            rating: rating,
                          );
                          Navigator.pop(ctx);
                        },
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
