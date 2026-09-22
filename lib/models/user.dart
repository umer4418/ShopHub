class ShopUser {
  final String? id;
  final String name;
  final String email;
  final String password;
  final String phone;
  final bool isAdmin;
  final String role;

  const ShopUser({
    this.id,
    required this.name,
    required this.email,
    this.password = '',
    this.phone = '',
    this.isAdmin = false,
    String? role,
  }) : role = role ?? (isAdmin ? 'admin' : 'customer');

  ShopUser copyWith({
    String? id,
    String? name,
    String? email,
    String? password,
    String? phone,
    bool? isAdmin,
    String? role,
  }) {
    return ShopUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      phone: phone ?? this.phone,
      isAdmin: isAdmin ?? this.isAdmin,
      role: role ?? this.role,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'isAdmin': isAdmin,
        'is_admin': isAdmin,
        'role': role,
      };

  factory ShopUser.fromJson(Map<String, dynamic> json) {
    final isAdmin = (json['isAdmin'] as bool?) ??
        (json['is_admin'] as bool?) ??
        (json['role'] == 'admin');
    return ShopUser(
      id: json['id'] as String?,
      name: (json['name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      password: (json['password'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      isAdmin: isAdmin,
      role: (json['role'] as String?) ?? (isAdmin ? 'admin' : 'customer'),
    );
  }
}
