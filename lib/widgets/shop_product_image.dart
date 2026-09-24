import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/colors.dart';

/// ShopProductImage
/// Resilient product image widget that handles network images, asset images,
/// loading states, and elegant fallbacks so product pictures ALWAYS display.
class ShopProductImage extends StatelessWidget {
  const ShopProductImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.categoryId,
    this.productName,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final String? categoryId;
  final String? productName;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = Product.resolveImageUrl(
      imageUrl,
      categoryId: categoryId,
      name: productName,
    );

    Widget imageWidget;

    if (resolvedUrl.startsWith('http://') || resolvedUrl.startsWith('https://')) {
      imageWidget = Image.network(
        resolvedUrl,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          final total = loadingProgress.expectedTotalBytes;
          final loaded = loadingProgress.cumulativeBytesLoaded;
          final progress = total != null && total > 0 ? loaded / total : null;

          return Container(
            width: width,
            height: height,
            color: const Color(0xFFF1F5F9),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: progress,
                  color: ShopColors.primary.withValues(alpha: 0.6),
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildFallback();
        },
      );
    } else if (resolvedUrl.startsWith('assets/')) {
      imageWidget = Image.asset(
        resolvedUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallback();
        },
      );
    } else {
      imageWidget = _buildFallback();
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildFallback() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: ShopColors.primarySoft,
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Icon(
          Icons.shopping_bag_outlined,
          color: ShopColors.primary.withValues(alpha: 0.8),
          size: (height != null && height! < 60) ? 20 : 32,
        ),
      ),
    );
  }
}
