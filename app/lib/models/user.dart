class User {
  final int id;
  final String username;
  final bool isAdmin;

  const User({required this.id, required this.username, required this.isAdmin});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      isAdmin: json['isAdmin'] == true,
    );
  }
}
