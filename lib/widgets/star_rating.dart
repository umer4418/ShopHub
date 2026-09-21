import 'package:flutter/material.dart';

import '../theme/colors.dart';

class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.rating, this.size = 14, this.count});

  final double rating;
  final double size;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          final filled = rating >= i + 1;
          final half = !filled && rating > i && rating < i + 1;
          return Icon(
            filled
                ? Icons.star
                : half
                    ? Icons.star_half
                    : Icons.star_border,
            size: size,
            color: ShopColors.star,
          );
        }),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(fontSize: size - 1, fontWeight: FontWeight.w600, color: ShopColors.text),
        ),
        if (count != null)
          Text(
            ' ($count)',
            style: TextStyle(fontSize: size - 2, color: ShopColors.muted),
          ),
      ],
    );
  }
}
