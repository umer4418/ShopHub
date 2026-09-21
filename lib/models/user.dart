class ShopUser {
  final String name;
  final String email;
  final String password;
  final String phone;
  final bool isAdmin;

  const ShopUser({
    required this.name,
    required this.email,
    required this.password,
    this.phone = '',
    this.isAdmin = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'isAdmin': isAdmin,
      };

  factory ShopUser.fromJson(Map<String, dynamic> json) => ShopUser(
        name: json['name'] as String,
        email: json['email'] as String,
        password: json['password'] as String,
        phone: json['phone'] as String? ?? '',
        isAdmin: json['isAdmin'] as bool? ?? false,
      );
}
