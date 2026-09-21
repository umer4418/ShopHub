import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/routes/app_routes.dart';
import '../controllers/product_controller.dart';
import '../theme/colors.dart';

class ShopSearchBar extends StatefulWidget {
  const ShopSearchBar({super.key, this.autofocus = false, this.onSubmitted});

  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  State<ShopSearchBar> createState() => _ShopSearchBarState();
}

class _ShopSearchBarState extends State<ShopSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<ProductController>().searchQuery,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productCtrl = context.read<ProductController>();
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search in ShopHub',
        prefixIcon: const Icon(Icons.search, color: ShopColors.muted),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
      onSubmitted: (q) {
        productCtrl.setSearch(q);
        if (widget.onSubmitted != null) {
          widget.onSubmitted!(q);
        } else {
          Navigator.pushNamed(context, AppRoutes.products);
        }
      },
    );
  }
}
