class Product {
  final String id;
  final String name;
  final String categoryId;
  final String imageUrl;
  final double price;
  final double originalPrice;
  final double rating;
  final int reviewCount;
  final String shortDescription;
  final String description;
  final int stock;
  final bool featured;
  final bool popular;

  const Product({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.imageUrl,
    required this.price,
    required this.originalPrice,
    required this.rating,
    required this.reviewCount,
    required this.shortDescription,
    required this.description,
    required this.stock,
    this.featured = false,
    this.popular = false,
  });

  int get discountPercent {
    if (originalPrice <= price) return 0;
    return (((originalPrice - price) / originalPrice) * 100).round();
  }

  Product copyWith({
    String? id,
    String? name,
    String? categoryId,
    String? imageUrl,
    double? price,
    double? originalPrice,
    double? rating,
    int? reviewCount,
    String? shortDescription,
    String? description,
    int? stock,
    bool? featured,
    bool? popular,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      shortDescription: shortDescription ?? this.shortDescription,
      description: description ?? this.description,
      stock: stock ?? this.stock,
      featured: featured ?? this.featured,
      popular: popular ?? this.popular,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'categoryId': categoryId,
        'category_id': categoryId,
        'imageUrl': imageUrl,
        'image_url': imageUrl,
        'price': price,
        'originalPrice': originalPrice,
        'original_price': originalPrice,
        'rating': rating,
        'reviewCount': reviewCount,
        'review_count': reviewCount,
        'shortDescription': shortDescription,
        'short_description': shortDescription,
        'description': description,
        'stock': stock,
        'featured': featured,
        'popular': popular,
      };

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'name': name,
        'category_id': categoryId,
        'image_url': imageUrl,
        'price': price,
        'original_price': originalPrice,
        'rating': rating,
        'review_count': reviewCount,
        'short_description': shortDescription,
        'description': description,
        'stock': stock,
        'featured': featured,
        'popular': popular,
      };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? '',
        categoryId: (json['categoryId'] ?? json['category_id'] ?? '') as String,
        imageUrl: (json['imageUrl'] ?? json['image_url'] ?? '') as String,
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        originalPrice: (json['originalPrice'] ?? json['original_price'] ?? json['price'] as num?)?.toDouble() ?? 0.0,
        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: (json['reviewCount'] ?? json['review_count'] as num?)?.toInt() ?? 0,
        shortDescription: (json['shortDescription'] ?? json['short_description'] ?? '') as String,
        description: (json['description'] as String?) ?? '',
        stock: (json['stock'] as num?)?.toInt() ?? 10,
        featured: (json['featured'] as bool?) ?? false,
        popular: (json['popular'] as bool?) ?? false,
      );
}
