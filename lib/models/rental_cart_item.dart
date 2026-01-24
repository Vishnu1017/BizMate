import 'package:bizmate/models/rental_item.dart';

class RentalCartItem {
  final RentalItem item;
  final int noOfDays;
  final double ratePerDay;
  final double totalAmount;
  final DateTime fromDateTime;
  final DateTime toDateTime;

  RentalCartItem({
    required this.item,
    required this.noOfDays,
    required this.ratePerDay,
    required this.totalAmount,
    required this.fromDateTime,
    required this.toDateTime,
  });
}
