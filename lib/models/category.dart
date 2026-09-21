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
      };

  factory ShopCategory.fromJson(Map<String, dynamic> json) => ShopCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String,
        imageUrl: json['imageUrl'] as String,
      );
}
