// lib/models/app_user.dart

/// Уровень роли. Чем больше — тем больше прав.
enum Role {
  reader(1),
  master(2),
  admin(3);

  final int level;
  const Role(this.level);

  static Role fromString(String? s) {
    switch (s) {
      case 'admin':
        return Role.admin;
      case 'master':
      case 'librarian': // алиас на всякий случай
        return Role.master;
      default:
        return Role.reader;
    }
  }

  String get label {
    switch (this) {
      case Role.admin:
        return 'Администратор';
      case Role.master:
        return 'Мастер';
      case Role.reader:
        return 'Клиент';
    }
  }
}

class AppUser {
  final int id;
  final String username;
  final String fullName;
  final String? email;
  final Role role;

  /// ← ПРАВКА: ссылка на клиента автосервиса.
  /// Заполнено у reader'ов (может создавать заказы только себе),
  /// для master/admin — null.
  final int? clientId;

  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.email,
    this.clientId, // ← ПРАВКА
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'fullName': fullName,
    'email': email,
    'role': role.name,
    'clientId': clientId, // ← ПРАВКА
  };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: (json['id'] as num?)?.toInt() ?? 0,
    username: json['username'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
    email: json['email'] as String?,
    role: Role.fromString(json['role'] as String?),
    clientId: (json['clientId'] as num?)?.toInt(), // ← ПРАВКА
  );
}
