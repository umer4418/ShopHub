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

  factory Product.fromJson(Map<String, dynamic> json) {
    final catId = (json['categoryId'] ?? json['category_id'] ?? '') as String;
    final rawImg = (json['imageUrl'] ?? json['image_url'] ?? '') as String;
    final name = (json['name'] as String?) ?? '';

    return Product(
      id: json['id'] as String,
      name: name,
      categoryId: catId,
      imageUrl: resolveImageUrl(rawImg, categoryId: catId, name: name),
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

  /// Resolves any asset path, invalid, or local URL to a reliable high-res image.
  static String resolveImageUrl(String? raw, {String? categoryId, String? name}) {
    if (raw == null || raw.trim().isEmpty) {
      return _fallbackForCategory(categoryId);
    }
    final trimmed = raw.trim();

    // Map legacy asset seeds or file paths to high-res Unsplash CDN images
    if (trimmed.contains('headphones') || trimmed.contains('p1')) {
      return 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=800';
    }
    if (trimmed.contains('smartwatch') || trimmed.contains('watch')) {
      return 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=800';
    }
    if (trimmed.contains('keyboard')) {
      return 'https://images.unsplash.com/photo-1587829741301-dc798b83add3?w=800';
    }
    if (trimmed.contains('earbuds')) {
      return 'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?w=800';
    }
    if (trimmed.contains('shirt') || trimmed.contains('tee')) {
      return 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=800';
    }
    if (trimmed.contains('jacket')) {
      return 'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=800';
    }
    if (trimmed.contains('sneaker') || trimmed.contains('shoe')) {
      return 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=800';
    }
    if (trimmed.contains('tote') || trimmed.contains('bag')) {
      return 'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=800';
    }
    if (trimmed.contains('chair')) {
      return 'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=800';
    }
    if (trimmed.contains('dinner') || trimmed.contains('ceramic') || trimmed.contains('plate')) {
      return 'https://images.unsplash.com/photo-1603190287605-4f70b49d5e3f?w=800';
    }
    if (trimmed.contains('diffuser') || trimmed.contains('lamp')) {
      return 'https://images.unsplash.com/photo-1608571423902-eed4a5ad8108?w=800';
    }
    if (trimmed.contains('serum') || trimmed.contains('beauty')) {
      return 'https://images.unsplash.com/photo-1620916566398-39f1143ab7be?w=800';
    }
    if (trimmed.contains('lip')) {
      return 'https://images.unsplash.com/photo-1586495777744-4413f21062fa?w=800';
    }
    if (trimmed.contains('yoga') || trimmed.contains('mat')) {
      return 'https://images.unsplash.com/photo-1601925260368-ae2f83cf8b7f?w=800';
    }
    if (trimmed.contains('dumbbell') || trimmed.contains('gym')) {
      return 'https://images.unsplash.com/photo-1517963879433-6ad2b056d712?w=800';
    }
    if (trimmed.contains('honey')) {
      return 'https://images.unsplash.com/photo-1587049352846-4a222e784d38?w=800';
    }
    if (trimmed.contains('rice')) {
      return 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=800';
    }
    if (trimmed.contains('block') || trimmed.contains('toy')) {
      return 'https://images.unsplash.com/photo-1587654780291-39c9404d746b?w=800';
    }
    if (trimmed.contains('book')) {
      return 'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=800';
    }
    if (trimmed.contains('speaker')) {
      return 'https://images.unsplash.com/photo-1545454675-3531b543be5d?w=800';
    }
    if (trimmed.contains('phone') || trimmed.contains('mobile')) {
      return 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=800';
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    return _fallbackForCategory(categoryId);
  }

  static String _fallbackForCategory(String? categoryId) {
    return switch (categoryId) {
      'electronics' => 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=800',
      'mobiles' || 'phones' => 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=800',
      'fashion' => 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=800',
      'home' => 'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=800',
      'beauty' => 'https://images.unsplash.com/photo-1620916566398-39f1143ab7be?w=800',
      'sports' => 'https://images.unsplash.com/photo-1517963879433-6ad2b056d712?w=800',
      'grocery' || 'groceries' => 'https://images.unsplash.com/photo-1587049352846-4a222e784d38?w=800',
      'kids' || 'baby' => 'https://images.unsplash.com/photo-1587654780291-39c9404d746b?w=800',
      _ => 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=800',
    };
  }
}
