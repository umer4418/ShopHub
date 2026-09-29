import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/product_controller.dart';
import '../theme/colors.dart';

class ShopSearchBar extends StatefulWidget {
  const ShopSearchBar({
    super.key,
    this.autofocus = false,
    this.onSubmitted,
    this.hintText = 'Search products, brands and categories...',
  });

  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final String hintText;

  @override
  State<ShopSearchBar> createState() => _ShopSearchBarState();
}

class _ShopSearchBarState extends State<ShopSearchBar> {
  late final TextEditingController _controller;
  Worker? _searchWorker;

  @override
  void initState() {
    super.initState();
    final initial = Get.isRegistered<ProductController>()
        ? Get.find<ProductController>().searchQuery
        : '';
    _controller = TextEditingController(text: initial);
    _controller.addListener(() {
      if (mounted) setState(() {});
    });

    if (Get.isRegistered<ProductController>()) {
      _searchWorker = ever<String>(
        Get.find<ProductController>().searchQueryRx,
        (q) {
          if (mounted && _controller.text != q) {
            _controller.text = q;
            setState(() {});
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _searchWorker?.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmit(String q) {
    if (Get.isRegistered<ProductController>()) {
      Get.find<ProductController>().setSearch(q);
    }
    if (widget.onSubmitted != null) {
      widget.onSubmitted!(q);
    } else {
      Navigator.pushNamed(context, AppRoutes.products);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        textInputAction: TextInputAction.search,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: ShopColors.text,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 14, right: 10),
            child: Icon(
              Icons.search_rounded,
              color: ShopColors.primary,
              size: 22,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 24),
          suffixIcon: hasText
              ? IconButton(
                  icon: const Icon(
                    Icons.cancel,
                    size: 18,
                    color: ShopColors.muted,
                  ),
                  onPressed: () {
                    _controller.clear();
                    if (Get.isRegistered<ProductController>()) {
                      Get.find<ProductController>().setSearch('');
                    }
                  },
                )
              : IconButton(
                  tooltip: 'Filter Products',
                  icon: const Icon(
                    Icons.tune_rounded,
                    size: 19,
                    color: ShopColors.muted,
                  ),
                  onPressed: () => _handleSubmit(_controller.text),
                ),
          suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 24),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        onChanged: (val) {
          if (Get.isRegistered<ProductController>()) {
            Get.find<ProductController>().setSearch(val);
          }
        },
        onSubmitted: _handleSubmit,
      ),
    );
  }
}
