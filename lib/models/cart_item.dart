import 'product.dart';

class CartItem {
  final String? id;
  final String? userId;
  final Product product;
  final int quantity;

  const CartItem({
    this.id,
    this.userId,
    required this.product,
    required this.quantity,
  });

  double get lineTotal => product.price * quantity;

  CartItem copyWith({
    String? id,
    String? userId,
    Product? product,
    int? quantity,
  }) =>
      CartItem(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        product: product ?? this.product,
        quantity: quantity ?? this.quantity,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (userId != null) 'userId': userId,
        if (userId != null) 'user_id': userId,
        'product': product.toJson(),
        'quantity': quantity,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    Product prod;
    final pData = json['product'] ?? json['product_data'];
    if (pData is Map<String, dynamic>) {
      prod = Product.fromJson(pData);
    } else {
      final pid = json['product_id']?.toString() ?? '';
      prod = Product(
        id: pid,
        name: json['product_name']?.toString() ?? 'Product $pid',
        categoryId: '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        originalPrice: (json['original_price'] as num?)?.toDouble() ?? 0.0,
        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
        imageUrl: json['image_url']?.toString() ?? '',
        shortDescription: '',
        description: '',
        stock: 10,
      );
    }

    return CartItem(
      id: json['id']?.toString(),
      userId: json['userId'] as String? ?? json['user_id'] as String?,
      product: prod,
      quantity: (json['quantity'] as num?)?.toInt() ??
          (json['count'] as num?)?.toInt() ??
          1,
    );
  }

  factory CartItem.fromSupabase(Map<String, dynamic> map, [Product? matchedProduct]) {
    Product prod;
    if (matchedProduct != null) {
      prod = matchedProduct;
    } else if (map['product_data'] != null &&
        map['product_data'] is Map<String, dynamic> &&
        (map['product_data'] as Map).isNotEmpty) {
      prod = Product.fromJson(map['product_data'] as Map<String, dynamic>);
    } else {
      final pid = map['product_id']?.toString() ?? '';
      prod = Product(
        id: pid,
        name: map['name']?.toString() ?? 'Product $pid',
        categoryId: '',
        price: 0.0,
        originalPrice: 0.0,
        rating: 0.0,
        reviewCount: 0,
        imageUrl: '',
        shortDescription: '',
        description: '',
        stock: 10,
      );
    }

    return CartItem(
      id: map['id']?.toString(),
      userId: map['user_id']?.toString(),
      product: prod,
      quantity: (map['quantity'] as num?)?.toInt() ??
          (map['count'] as num?)?.toInt() ??
          1,
    );
  }

  Map<String, dynamic> toSupabaseMap(String uId) => {
        'user_id': uId,
        'product_id': product.id,
        'quantity': quantity,
        'count': quantity,
        'product_data': product.toJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
}
