class User {
  final String id;
  final String name;
  final String? avatar;

  User({required this.id, required this.name, this.avatar});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String?,
    );
  }
}