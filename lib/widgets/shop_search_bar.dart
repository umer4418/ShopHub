import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/product_controller.dart';
import '../theme/colors.dart';

class ShopSearchBar extends StatefulWidget {
  const ShopSearchBar({
    super.key,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.onFilterTap,
    this.hasActiveFilters = false,
    this.hintText = 'Search products, brands and categories...',
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final VoidCallback? onFilterTap;
  final bool hasActiveFilters;
  final String hintText;

  @override
  State<ShopSearchBar> createState() => _ShopSearchBarState();
}

class _ShopSearchBarState extends State<ShopSearchBar> {
  late final TextEditingController _controller;
  bool _isInternalController = false;
  Worker? _searchWorker;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _isInternalController = false;
    } else {
      _isInternalController = true;
      final initial = Get.isRegistered<ProductController>()
          ? Get.find<ProductController>().searchQuery
          : '';
      _controller = TextEditingController(text: initial);
    }

    _controller.addListener(_onControllerChanged);

    if (_isInternalController && Get.isRegistered<ProductController>()) {
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

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchWorker?.dispose();
    _controller.removeListener(_onControllerChanged);
    if (_isInternalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleSubmit(String q) {
    if (widget.onSubmitted != null) {
      widget.onSubmitted!(q);
    } else {
      if (Get.isRegistered<ProductController>()) {
        Get.find<ProductController>().setSearch(q);
      }
      Navigator.pushNamed(context, AppRoutes.products);
    }
  }

  void _handleClear() {
    _controller.clear();
    if (widget.onClear != null) {
      widget.onClear!();
    } else if (widget.onChanged != null) {
      widget.onChanged!('');
    } else if (Get.isRegistered<ProductController>()) {
      Get.find<ProductController>().setSearch('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;

    Widget suffixWidget;
    if (widget.onFilterTap != null) {
      if (hasText) {
        suffixWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                size: 19,
                color: ShopColors.muted,
              ),
              tooltip: 'Clear',
              onPressed: _handleClear,
            ),
            IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 19,
                    color: widget.hasActiveFilters
                        ? ShopColors.primary
                        : ShopColors.muted,
                  ),
                  if (widget.hasActiveFilters)
                    Positioned(
                      top: -1,
                      right: -1,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: ShopColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              tooltip: 'Filter Categories',
              onPressed: widget.onFilterTap,
            ),
          ],
        );
      } else {
        suffixWidget = IconButton(
          tooltip: 'Filter Categories',
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 19,
                color: widget.hasActiveFilters
                    ? ShopColors.primary
                    : ShopColors.muted,
              ),
              if (widget.hasActiveFilters)
                Positioned(
                  top: -1,
                  right: -1,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: ShopColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          onPressed: widget.onFilterTap,
        );
      }
    } else {
      suffixWidget = hasText
          ? IconButton(
              icon: const Icon(
                Icons.cancel,
                size: 18,
                color: ShopColors.muted,
              ),
              onPressed: _handleClear,
            )
          : IconButton(
              tooltip: 'Filter Products',
              icon: const Icon(
                Icons.tune_rounded,
                size: 19,
                color: ShopColors.muted,
              ),
              onPressed: () => _handleSubmit(_controller.text),
            );
    }

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
        focusNode: widget.focusNode,
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
          suffixIcon: suffixWidget,
          suffixIconConstraints: BoxConstraints(
            minWidth: (widget.onFilterTap != null && hasText) ? 72 : 40,
            minHeight: 24,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        onChanged: (val) {
          if (widget.onChanged != null) {
            widget.onChanged!(val);
          } else if (Get.isRegistered<ProductController>()) {
            Get.find<ProductController>().setSearch(val);
          }
        },
        onSubmitted: _handleSubmit,
      ),
    );
  }
}
