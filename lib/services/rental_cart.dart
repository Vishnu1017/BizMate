import '../models/rental_cart_item.dart';

class RentalCart {
  static final List<RentalCartItem> _items = [];

  static List<RentalCartItem> get items => _items;

  static void add(RentalCartItem item) {
    _items.add(item);
  }

  static void clear() {
    _items.clear();
  }

  static bool get isEmpty => _items.isEmpty;

  static double get totalAmount =>
      _items.fold(0.0, (sum, item) => sum + item.totalAmount);
}
