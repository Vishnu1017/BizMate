import 'package:hive/hive.dart';

part 'rental_item.g.dart';

@HiveType(typeId: 4)
class RentalItem {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final String brand;

  @HiveField(2)
  final String category;

  @HiveField(3)
  final double price;

  @HiveField(4)
  final String availability;

  @HiveField(5)
  final String imagePath;

  @HiveField(6)
  final List<RentalBooking> bookedSlots; // mutable list

  @HiveField(7)
  final String condition; // ⭐ NEW FIELD ADDED

  RentalItem({
    required this.name,
    required this.brand,
    required this.category,
    required this.price,
    required this.availability,
    required this.imagePath,
    List<RentalBooking>? bookedSlots,
    String? condition, // allow null
  }) : bookedSlots = bookedSlots ?? [],
       condition = condition ?? "Excellent"; // DEFAULT VALUE
}

@HiveType(typeId: 5)
class RentalBooking {
  @HiveField(0)
  final DateTime from;

  @HiveField(1)
  final DateTime to;

  RentalBooking({required this.from, required this.to});

  get itemName => null;
}
