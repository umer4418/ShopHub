class ShopCategory {
  final String id;
  final String name;
  final String icon;
  final String imageUrl;

  const ShopCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'imageUrl': imageUrl,
        'image_url': imageUrl,
      };

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'image_url': imageUrl,
      };

  factory ShopCategory.fromJson(Map<String, dynamic> json) => ShopCategory(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? '',
        icon: (json['icon'] as String?) ?? 'category',
        imageUrl: (json['imageUrl'] ?? json['image_url'] ?? '') as String,
      );
}
