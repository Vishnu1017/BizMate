import 'package:hive/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: 0)
class User extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String email;

  @HiveField(2)
  String phone;

  @HiveField(3)
  String password;

  @HiveField(4)
  String role;

  @HiveField(5)
  String upiId;

  @HiveField(6)
  String imageUrl;

  @HiveField(7)
  String? passcode;

  @HiveField(8)
  String? address;

  User({
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    required this.role,
    this.address = '',
    this.upiId = '',
    this.imageUrl = '', // ✅ Default value avoids missing argument errors
  });
}
